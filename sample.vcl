vcl 4.1;

# Define a probe to check backend health
probe my_probe {
    .url = "/";
    .timeout = 1s;
    .interval = 5s;
    .window = 5;
    .threshold = 3;
}

# Configure the backend server
backend default {
    .host = "127.0.0.1";
    .port = "8080";
    .probe = my_probe;
}

# Handle incoming requests
sub vcl_recv {
    # Bypass cache for admin pages
    if (req.url ~ "^/admin") {
        return (pass);
    }

    # Cache static files
    if (req.url ~ "\.(jpg|jpeg|png|gif|css|js)$") {
        return (hash);
    }

    # For all other requests, proceed with normal caching
    return (hash);
}

# Handle backend responses
sub vcl_backend_response {
    # Cache static content for 1 hour
    if (bereq.url ~ "\.(jpg|jpeg|png|gif|css|js)$") {
        set beresp.ttl = 1h;
    }

    # Cache dynamic content for 10 minutes
    if (bereq.url ~ "^/blog" || bereq.url ~ "\.html$") {
        set beresp.ttl = 10m;
        set beresp.grace = 1h;  # Serve stale content for 1 hour if backend is slow
    }

    return (deliver);
}

# Handle cache hits
sub vcl_hit {
    # Deliver directly if cached
    return (deliver);
}

# Handle cache misses
sub vcl_miss {
    # Fetch from backend
    return (fetch);
}

# Deliver response to client
sub vcl_deliver {
    # Add a custom header to indicate cache status
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }

    return (deliver);
}

# Handle synthetic responses (e.g., error pages)
sub vcl_synth {
    set resp.http.Content-Type = "text/html; charset=utf-8";
    synthetic({"
        <html>
        <body>
            <h1>" + resp.status + " " + resp.reason + "</h1>
        </body>
        </html>
    "});
    return (deliver);
}

# Handle backend errors
sub vcl_backend_error {
    set beresp.http.Content-Type = "text/html; charset=utf-8";
    synthetic({"
        <html>
        <body>
            <h1>Backend Error</h1>
            <p>Sorry, something went wrong.</p>
        </body>
        </html>
    "});
    return (deliver);
}
