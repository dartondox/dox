# Deployment

## Build

Compile dart into machine code.

```py
dox build
```

Start the application.

```py
bin/server
```

## Nginx Configuration

Running server with Nginx reverse proxy.

```py
server {
  listen 80;

  server_name <YOUR_APP_DOMAIN.COM>;

  location / {
    proxy_pass http://localhost:<APP_PORT>;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_cache_bypass $http_upgrade;
  }
}
```