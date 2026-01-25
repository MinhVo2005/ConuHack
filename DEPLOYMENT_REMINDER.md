# Deployment Reminder

## TODO Before Demo

- [ ] Deploy backend server to cloud provider
- [ ] Get a domain name for the API
- [ ] Update Flutter app with production URL
- [ ] Update game frontend with production URL

## Suggested Providers (Free Tier Friendly)

| Provider | Service | Notes |
|----------|---------|-------|
| Railway | Backend hosting | Easy Python/FastAPI deploy |
| Render | Backend hosting | Free tier available |
| Fly.io | Backend hosting | Good for WebSockets |
| Vercel | Game frontend | Static hosting |
| Netlify | Game frontend | Static hosting |

## Domain Options

- Namecheap (cheap domains)
- Cloudflare (free DNS + proxy)
- FreeDNS (free subdomains for testing)

## Environment Variables to Set

```env
# Production
API_URL=https://your-domain.com
SOCKET_URL=wss://your-domain.com
```

## Post-Deploy Checklist

- [ ] Test Socket.IO connection works over WSS
- [ ] Verify CORS settings allow Flutter app origin
- [ ] Test all API endpoints
- [ ] Confirm database persistence
