# Buoy Web portal

Web dashboard for the Buoy ROS 2 hub appliance.

## Local development

Run the web portal locally with **live reload** so UI changes appear instantly in the browser.

### Prerequisites

- **Node.js** (via asdf): `asdf install` in the repo root (uses `.tool-versions`)
- **pnpm** via corepack (run once):

  ```bash
  corepack enable
  ```

  Then install deps:

  ```bash
  cd command_center
  pnpm install
  ```

  If you prefer npm: `npm install` works too; use `npm run dev` instead of `pnpm dev`.

### Build (for Pi deployment)

Assets (Tailwind CSS, roslib, vis-network) are bundled locally so the UI works **offline** on the Pi (no CDN). The image build runs `pnpm run build` automatically when the playbook runs with network—no need to commit built files.

For local dev or manual deploy, run:

```bash
cd command_center
pnpm run build
```

### Run dev server

```bash
cd command_center
pnpm dev
```

Then open **http://localhost:8080**. The dev server:

- Runs the Express server on port 8080
- Restarts automatically when `server.js` changes (nodemon)
- For HTML/CSS/JS in `public/`: refresh the browser manually (no server restart needed)

### API behavior in dev

- `/api/devices` returns `[]` if no DHCP leases file exists (local)
- `/api/wifi` GET returns empty; POST will fail (no hostapd config)
- ROS status shows "Disconnected" unless rosbridge is running on `localhost:9090`

That’s fine for UI work. Edit HTML, CSS, and JS in `public/` and see changes immediately.
