//! Filtering HTTP proxy.
//!
//! Runs on 127.0.0.1:{dynamic_port} with a private single-threaded Tokio
//! runtime on a background std::thread. All WebView2 traffic routes here.
//!
//! Uses `LocalSet` + `spawn_local` because `adblock::Engine` is !Send.
//!
//! Handles two request types:
//! - CONNECT host:443 → TCP tunnel (bidirectional copy)
//! - GET/POST http://host/path → forward via reqwest

use std::rc::Rc;
use tokio::sync::oneshot;
use tokio::net::TcpStream;
use tokio::task::LocalSet;
use hyper::body::Incoming;
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::{Method, Request, Response, StatusCode};
use hyper_util::rt::TokioIo;
use http_body_util::{BodyExt, Full};

use crate::filter::AdblockFilter;
use crate::bridge;

/// Command sent from the main thread to the proxy thread.
pub(crate) enum ProxyCommand {
    UpdateFilters(oneshot::Sender<anyhow::Result<()>>),
    GetStats(oneshot::Sender<String>),
}

/// Handle to the running proxy server.
pub struct ProxyServer {
    shutdown_tx: Option<oneshot::Sender<()>>,
    pub(crate) cmd_tx: tokio::sync::mpsc::UnboundedSender<ProxyCommand>,
    _thread: Option<std::thread::JoinHandle<()>>,
    pub port: u16,
}

impl ProxyServer {
    /// Signal the proxy to shut down gracefully.
    pub fn shutdown(mut self) {
        if let Some(tx) = self.shutdown_tx.take() {
            let _ = tx.send(());
        }
    }
}

/// Shared state available to each proxy request handler.
/// Rc, not Arc — lives on the single-threaded LocalSet.
struct ProxyState {
    client: reqwest::Client,
    filter: Rc<AdblockFilter>,
}

/// Start the filtering proxy. Returns a handle with the bound port.
pub fn start(cache_dir: &str) -> anyhow::Result<ProxyServer> {
    let cache_dir = cache_dir.to_string();

    // Bind synchronously so we can return the port immediately
    let std_listener = std::net::TcpListener::bind("127.0.0.1:0")?;
    let port = std_listener.local_addr()?.port();
    std_listener.set_nonblocking(true)?;

    let (shutdown_tx, shutdown_rx) = oneshot::channel::<()>();
    let (cmd_tx, cmd_rx) = tokio::sync::mpsc::unbounded_channel::<ProxyCommand>();

    let thread = std::thread::Builder::new()
        .name("loonbox-proxy".into())
        .spawn(move || {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("Failed to create Tokio runtime for proxy");

            let local = LocalSet::new();

            local.block_on(&rt, async move {
                let listener = tokio::net::TcpListener::from_std(std_listener)
                    .expect("Failed to convert TcpListener");

                let filter = Rc::new(AdblockFilter::new(&cache_dir));
                let state = Rc::new(ProxyState {
                    client: reqwest::Client::builder()
                        .no_proxy()
                        .build()
                        .expect("Failed to build reqwest client"),
                    filter: filter.clone(),
                });

                log::info!("Browser proxy listening on 127.0.0.1:{}", port);

                let mut shutdown_rx = shutdown_rx;
                let mut cmd_rx = cmd_rx;

                loop {
                    tokio::select! {
                        accept = listener.accept() => {
                            match accept {
                                Ok((stream, _addr)) => {
                                    let state = state.clone();
                                    tokio::task::spawn_local(async move {
                                        if let Err(e) = serve_connection(stream, state).await {
                                            log::debug!("Proxy connection error: {}", e);
                                        }
                                    });
                                }
                                Err(e) => {
                                    log::warn!("Proxy accept error: {}", e);
                                }
                            }
                        }
                        Some(cmd) = cmd_rx.recv() => {
                            match cmd {
                                ProxyCommand::UpdateFilters(reply) => {
                                    let result = filter.update_from_network().await;
                                    let _ = reply.send(result);
                                }
                                ProxyCommand::GetStats(reply) => {
                                    let stats = filter.get_stats();
                                    let json = serde_json::to_string(&stats).unwrap_or_default();
                                    let _ = reply.send(json);
                                }
                            }
                        }
                        _ = &mut shutdown_rx => {
                            log::info!("Browser proxy shutting down");
                            break;
                        }
                    }
                }
            });
        })?;

    log::info!("Browser proxy bound to 127.0.0.1:{}", port);

    Ok(ProxyServer {
        shutdown_tx: Some(shutdown_tx),
        cmd_tx,
        _thread: Some(thread),
        port,
    })
}

/// Serve a single HTTP connection (may carry multiple requests via keep-alive).
async fn serve_connection(
    stream: TcpStream,
    state: Rc<ProxyState>,
) -> anyhow::Result<()> {
    let io = TokioIo::new(stream);

    let service = service_fn(move |req: Request<Incoming>| {
        let state = state.clone();
        async move { handle_request(req, state).await }
    });

    http1::Builder::new()
        .preserve_header_case(true)
        .title_case_headers(true)
        .serve_connection(io, service)
        .with_upgrades()
        .await?;

    Ok(())
}

/// Route a request to the appropriate handler.
async fn handle_request(
    req: Request<Incoming>,
    state: Rc<ProxyState>,
) -> Result<Response<Full<bytes::Bytes>>, hyper::Error> {
    if req.method() == Method::CONNECT {
        handle_connect(req, state).await
    } else {
        handle_http(req, state).await
    }
}

/// Empty 204 response for blocked requests.
fn blocked_response() -> Response<Full<bytes::Bytes>> {
    Response::builder()
        .status(StatusCode::NO_CONTENT)
        .body(Full::default())
        .unwrap()
}

/// Handle CONNECT tunnels (HTTPS). Establish a TCP tunnel.
async fn handle_connect(
    req: Request<Incoming>,
    state: Rc<ProxyState>,
) -> Result<Response<Full<bytes::Bytes>>, hyper::Error> {
    let host = req.uri().authority().map(|a| a.to_string()).unwrap_or_default();

    // Skip filtering for trusted domains
    let domain = host.split(':').next().unwrap_or(&host);
    if !bridge::is_trusted_url(&format!("https://{}/", domain)) {
        if state.filter.should_block_domain(&host) {
            log::debug!("Blocked CONNECT to {}", host);
            return Ok(blocked_response());
        }
    }

    // Spawn a task that waits for the upgrade, then tunnels
    tokio::task::spawn_local(async move {
        match hyper::upgrade::on(req).await {
            Ok(upgraded) => {
                if let Err(e) = tunnel(upgraded, &host).await {
                    log::debug!("Tunnel to {} failed: {}", host, e);
                }
            }
            Err(e) => {
                log::debug!("CONNECT upgrade failed for {}: {}", host, e);
            }
        }
    });

    // Return 200 to signal the client to start the tunnel
    Ok(Response::new(Full::default()))
}

/// Bidirectional TCP tunnel for CONNECT method.
async fn tunnel(
    upgraded: hyper::upgrade::Upgraded,
    host: &str,
) -> anyhow::Result<()> {
    let mut server = TcpStream::connect(host).await?;
    let mut client = TokioIo::new(upgraded);

    let (mut client_rd, mut client_wr) = tokio::io::split(&mut client);
    let (mut server_rd, mut server_wr) = server.split();

    let client_to_server = tokio::io::copy(&mut client_rd, &mut server_wr);
    let server_to_client = tokio::io::copy(&mut server_rd, &mut client_wr);

    tokio::select! {
        r = client_to_server => { r?; }
        r = server_to_client => { r?; }
    }

    Ok(())
}

/// Handle plain HTTP requests — forward via reqwest.
async fn handle_http(
    req: Request<Incoming>,
    state: Rc<ProxyState>,
) -> Result<Response<Full<bytes::Bytes>>, hyper::Error> {
    let method = req.method().clone();
    let uri = req.uri().to_string();
    let headers = req.headers().clone();

    // Check adblock filter (skip for trusted domains)
    if !bridge::is_trusted_url(&uri) {
        if state.filter.should_block(&uri, &uri, "other") {
            log::debug!("Blocked HTTP request to {}", uri);
            return Ok(blocked_response());
        }
    }

    // Collect the request body
    let body_bytes = match req.into_body().collect().await {
        Ok(collected) => collected.to_bytes(),
        Err(_) => bytes::Bytes::new(),
    };

    // Build reqwest request
    let mut builder = state.client.request(
        reqwest::Method::from_bytes(method.as_str().as_bytes()).unwrap_or(reqwest::Method::GET),
        &uri,
    );

    // Forward headers (skip hop-by-hop)
    for (name, value) in headers.iter() {
        let n = name.as_str();
        if n == "host" || n == "proxy-connection" || n == "proxy-authorization" {
            continue;
        }
        if let Ok(v) = value.to_str() {
            builder = builder.header(n, v);
        }
    }

    if !body_bytes.is_empty() {
        builder = builder.body(body_bytes.to_vec());
    }

    // Execute the upstream request
    match builder.send().await {
        Ok(resp) => {
            let status = StatusCode::from_u16(resp.status().as_u16())
                .unwrap_or(StatusCode::BAD_GATEWAY);

            let resp_bytes = resp.bytes().await.unwrap_or_default();

            let response = Response::builder()
                .status(status)
                .body(Full::new(resp_bytes))
                .unwrap();
            Ok(response)
        }
        Err(e) => {
            log::warn!("Proxy upstream error for {}: {}", uri, e);
            let response = Response::builder()
                .status(StatusCode::BAD_GATEWAY)
                .body(Full::new(bytes::Bytes::from(format!("Proxy error: {}", e))))
                .unwrap();
            Ok(response)
        }
    }
}
