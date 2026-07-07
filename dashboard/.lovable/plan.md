## Refresh code from `Singhal861/github-gateway` via GitHub sync

### Situation
- The repo `https://github.com/Singhal861/github-gateway.git` returns **404** from public GitHub API calls, which means it is either **private** or the name is slightly different.
- I cannot pull code from a private repo directly from the agent side. GitHub sync must be authorized by you through the Lovable UI — after that, it's fully automatic and bidirectional (Lovable ↔ GitHub).

### Steps for you (one-time, in the Lovable UI)
1. Bottom-left of the chat input → **+ (Plus) menu** → **GitHub** → **Connect project**.
2. Authorize the **Lovable GitHub App** on the `Singhal861` account/org and grant access to the `github-gateway` repository.
3. Back in Lovable, choose **Connect existing repository** → pick `Singhal861/github-gateway` → branch `main`.
4. Lovable will pull the current repo contents into this project and then keep them in sync automatically (pushes to `main` refresh Lovable, and Lovable edits push back to `main`).

### What happens next (my side, after sync is live)
- No code changes needed from me for the sync itself.
- Once the repo files land in this project, I can:
  - Reconcile the incoming files with the current FIFA dashboard (`src/components/fifa/*`, `src/lib/fifa/*`, `public/data/req_*.json`) if there are conflicts.
  - Fix any build/type errors introduced by the pulled code.
  - Wire any new JSON files or requirements into the existing components.

### If the repo name is different
If the actual repo isn't `github-gateway`, tell me the correct `owner/repo` and branch and I'll adjust — but the connection step above is still the same flow.

### Notes / limitations
- Lovable currently supports **connecting one GitHub account per Lovable account**, and **cannot import an existing repo into a brand-new empty project** without going through this connect flow.
- Direct HTTP fetches from the agent won't work for private repos and aren't a substitute for real sync — GitHub sync is the correct mechanism.

No files will be edited by me in this plan; the action is the UI connection on your side. Ping me once the repo is connected and I'll reconcile the pulled contents.
