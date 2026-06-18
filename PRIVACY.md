# Privacy

Codex Reset Watcher is read-only.

The app reads your existing Codex Desktop login from:

```text
~/.codex/auth.json
```

It uses that login to call:

```text
https://chatgpt.com/backend-api/wham/rate-limit-reset-credits
```

The app does not:

- ask for an OpenAI API key
- redeem or modify reset credits
- send data to third-party services
- include analytics
- copy or store your token outside the running app process

If the endpoint or Codex auth format changes, the app may stop working.
