# Parc IT Web

The web client is a React, TypeScript, and Vite progressive web app. It uses the existing Node.js API; no database credentials belong in the browser.

## Development

```bash
npm ci
npm run dev
```

By default, local development sends API requests to `http://localhost:3000/api`. Set `VITE_API_BASE_URL` when the API runs elsewhere.

## Production build

```bash
npm run build
```

The build is emitted to the repository-level `public/` directory for Vercel. The root `npm run build` runs this command for deployment.
