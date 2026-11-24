# TwinMind AI

TwinMind AI is a full-stack career intelligence application. It lets users create an account, build a persistent career profile, identify skill gaps for a target role, and receive tailored next-step guidance.

## Technology

- Frontend: Next.js, React, TypeScript, Tailwind CSS
- Backend: FastAPI, Pydantic, SQLite

## Features

- Secure local account registration and login with scrypt password hashing.
- Persistent, account-scoped Digital Twin profiles.
- Weighted skill-gap and career-readiness analysis for AI Engineer, Data Scientist, and Backend Developer roles.
- Context-aware career guidance for learning plans, resumes, and interview preparation.
- Browser speech playback for agent responses.

## Run locally

1. Set up the backend environment:

   ```powershell
   cd backend
   python -m venv .venv
   .\.venv\Scripts\Activate.ps1
   pip install -r requirements.txt
   ```

2. Install frontend dependencies:

   ```powershell
   cd ..\frontend
   npm install
   ```

3. From the project root, start both applications:

   ```powershell
   .\start-twinmind.ps1
   ```

The web application runs at `http://localhost:3000`; the API runs at `http://127.0.0.1:8000`.

## Data storage

The backend stores application records in SQLite. Locally the default database is
`backend/twinmind.db`; on Render it is `/data/twinmind.db` on the persistent disk
declared in `render.yaml`. The `users`, `sessions`, `twin_profiles`,
`agent_conversations`, and `subscriptions` tables are keyed by account. Session
tokens are stored as hashes and expire after 30 days. CSV uploads and research
queries are processed for the request and are not retained. The database file is
ignored by Git and must not be committed.

SQLite is suitable for this single-instance deployment. Keep one backend instance
attached to the persistent disk and take regular database backups. A consistent
local backup can be made with Python's SQLite backup API:

```powershell
python -c "import sqlite3; source=sqlite3.connect('backend/twinmind.db'); target=sqlite3.connect('backend/twinmind-backup.db'); source.backup(target); target.close(); source.close()"
```

Free accounts include the saved Digital Twin, role readiness, career workflows,
career guidance, and the general AI assistant with saved conversation history.
General LLM answers require an `OPENAI_API_KEY` on the backend; the assistant
shows setup instructions when the key is missing. Pro access is
reserved for live research and is granted only while the Stripe subscription is
active or trialing. Checkout requires a configured Stripe recurring Price.

## OpenAI-powered assistant

The general AI assistant can answer open-ended questions with OpenAI and remembers
recent chat context. It does not require a TwinMind subscription. Create an API key
from the [OpenAI API key page](https://platform.openai.com/api-keys) and add it
before starting the backend. A ChatGPT subscription does not include API usage;
API billing is managed separately.

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:OPENAI_API_KEY = "your_api_key"
# Optional: choose a model; defaults to gpt-4o.
$env:TWINMIND_LLM_MODEL = "gpt-4o"
```

For a persistent local setup, copy `backend/.env.example` to `backend/.env` and add
your key there. `backend/.env` is ignored by Git and is loaded only by the backend.

Keep the key on the backend only; never place it in a frontend `NEXT_PUBLIC_` variable.

## Google sign-in setup

Google sign-in requires the same OAuth 2.0 **Web application** client ID in both
the frontend and backend. Set `NEXT_PUBLIC_GOOGLE_CLIENT_ID` in the frontend
environment and `GOOGLE_CLIENT_ID` in the backend environment. For local
development, add them to `frontend/.env.local` and `backend/.env` respectively.
The frontend API base URL can be set with `NEXT_PUBLIC_API_URL` (defaults to
`http://127.0.0.1:8000` locally).

In Google Cloud Console, configure the OAuth consent screen, then add each site
address you use (for example `http://localhost:3000` and your deployed frontend
origin) under **Authorized JavaScript origins** for that web client. No redirect
URI is used by this credential flow. For a deployed frontend, also set
`CORS_ALLOWED_ORIGINS` on the backend to a comma-separated list of the exact
frontend origins, including the scheme. A missing or mismatched client ID, an
unlisted browser origin, or a backend CORS origin mismatch will prevent sign-in.

Copy `frontend/.env.example` to `frontend/.env.local` and
`backend/.env.example` to `backend/.env`, then set real values. The `NEXT_PUBLIC_`
variables are embedded at frontend build time; rebuild/redeploy the frontend
after changing them. Google users are linked by verified email. New accounts are
sent through onboarding before the dashboard.

## Owner account activity

Set `ADMIN_EMAIL` in `backend/.env` to the owner's account email (the same verified
email used to sign in), then restart the backend. The owner can open `/admin` to
view registered users, saved career profile highlights, signup times, and recent
password or Google sign-in events. The backend checks the signed-in account on
every admin API request; other users receive a forbidden response. Set the same
`ADMIN_EMAIL` environment variable in the deployed backend to enable owner access
there. Authentication activity is recorded from the time this feature is enabled;
earlier sign-ins are not reconstructed.

## Stripe billing setup

Start in Stripe test mode. Create a TwinMind Pro product with a recurring monthly
Price, then copy its `price_...` ID into `STRIPE_PRO_PRICE_ID` in `backend/.env`.
Use the test secret key (`sk_test_...`) as `STRIPE_SECRET_KEY` and set
`FRONTEND_URL=http://localhost:3000`. The checkout uses Stripe-hosted Checkout
and keeps the configured Price on the server.

For local webhook delivery, install and sign in to the [Stripe CLI](https://docs.stripe.com/cli),
start the app, then run:

```powershell
stripe listen --forward-to localhost:8000/api/v1/payments/webhook
```

Copy the CLI's `whsec_...` signing secret into `STRIPE_WEBHOOK_SECRET` and
restart the backend. Complete a test checkout from `/pricing` using a Stripe
test payment method. The CLI forwards webhook events to the local endpoint and
prints delivery results.

For deployment, set `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`,
`STRIPE_PRO_PRICE_ID`, and `FRONTEND_URL` on the backend. Register the endpoint
`https://<backend-origin>/api/v1/payments/webhook` in Stripe and subscribe it to
`checkout.session.completed`, `customer.subscription.created`,
`customer.subscription.updated`, `customer.subscription.deleted`, `invoice.paid`,
and `invoice.payment_failed`. Enable and configure the Stripe customer billing
portal in the Stripe dashboard. Use matching live-mode keys, Price, and webhook
signing secret for production; do not mix test and live values. Subscription access is updated from verified
webhook events; a checkout return page by itself does not grant Pro. Without
Stripe credentials the app reports payments as unavailable instead of simulating
a purchase.

The Python runner uses RestrictedPython plus a short-lived child process, time
limit, output cap, and (where supported) process resource limits. RestrictedPython
explicitly does not claim to be an operating-system sandbox, so production code
execution stays disabled in `render.yaml`. A production deployment needs a
separately isolated execution service before enabling that endpoint; the local
`.env.example` setting is for development snippets only.

## API routes

- `POST /api/v1/auth/register`, `POST /api/v1/auth/login`, `POST /api/v1/auth/google` — create an account and session
- `GET /api/v1/auth/me`, `DELETE /api/v1/auth/logout` — session management
- `GET` and `PUT /api/v1/twin/profile` — read and save the signed-in user's profile
- `POST /api/v1/twin/analyze`, `POST /api/v1/twin/auto-sync` — role analysis and profile updates
- `POST /api/v1/agent/chat`, `GET /api/v1/agent/history` — career guidance and saved conversation history
- `POST /api/v1/omni/chat` — general AI assistant (requires backend OpenAI configuration)
- `POST /api/v1/research/search` — Pro live source search
- `GET /api/v1/payments/subscription`, `POST /api/v1/payments/create-checkout`, `POST /api/v1/payments/portal` — subscription and billing management
- `POST /api/v1/payments/webhook` — signed Stripe subscription updates

Authenticated API requests use the `X-Session-Token` header returned by login or registration.
