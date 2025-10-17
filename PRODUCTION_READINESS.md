# Production Readiness Checklist

Use this runbook to promote the activation/billing/compliance stack to production.

## 1) Environment Configuration

Set the following credentials/secrets in production (Rails credentials or ENV):

- Stripe
  - STRIPE_PUBLISHABLE_KEY
  - STRIPE_SECRET_KEY

- DocuSign (Production tenants)
  - DOCUSIGN_INTEGRATION_KEY (production app GUID)
  - DOCUSIGN_USER_ID (API user GUID that grants consent)
  - DOCUSIGN_PRIVATE_KEY_PATH (absolute path on server)
  - DOCUSIGN_BASE_URL=https://www.docusign.net/restapi

- App
  - RAILS_MASTER_KEY
  - REDIS_URL (for Sidekiq)
  - DATABASE_URL

## 2) DocuSign (switching from Demo → Production)

- Create a production DocuSign app; upload the RSA public key that matches the private key file you deploy.
- Add Redirect URIs (must be HTTPS). Example: https://your-domain.com/
- Grant consent once with the production auth host using the API user:
  - https://account.docusign.com/oauth/auth?response_type=code&scope=signature%20impersonation&client_id=INTEGRATION_KEY&redirect_uri=ENCODED_REDIRECT
- Verify the API user GUID matches DOCUSIGN_USER_ID and belongs to the target production account.

Notes:
- OAuth token/consent hosts: account.docusign.com (prod)
- REST API host: www.docusign.net (prod)

## 3) Stripe

- Rotate Stripe keys to production values.
- Ensure `config/initializers/stripe.rb` reads from production credentials.
- Webhooks (production endpoint):
  - Expose and configure Stripe webhooks for: checkout.session.completed, setup_intent.succeeded, payment_intent.succeeded (and any additional ones used).
  - Lock down webhook signing secret in credentials.

## 4) Webhooks & Inbound Endpoints

- Allowlist source IPs or protect with signatures where supported.
- Ensure HTTPS termination is in place.
- Double-check route paths match provider console configuration.

## 5) Background Jobs / Scheduling

- Sidekiq configured with REDIS_URL.
- Ensure MonthEndBillingJob is scheduled (via cron/scheduler) to run at month end:
  - Rake task: `rake billing:run_month_end_charges`
  - Or use Sidekiq Cron/Heroku Scheduler/OS cron.

## 6) Files & Keys on Host

- Place DocuSign private key file on server (outside repo) and set DOCUSIGN_PRIVATE_KEY_PATH to that file.
- Permissions: `chmod 600` on the key file; owned by deploy user.
- Ensure `config/docusign_private_key.pem` is NOT committed. `.gitignore` already ignores it.

## 7) Compliance Templates

- GSA template lives at `app/documents/gsa_template.docx`.
- For BAA, add `app/documents/baa_template.docx` and wire a similar renderer.
- Use placeholders like `{{organization_name}}`, `{{owner_name}}`, `{{owner_email}}`, `{{current_date}}`.

## 8) Content Security Policy (CSP)

- Allow Stripe.js and DocuSign signing URLs if rendered in-app.
- Example allowances: `https://js.stripe.com` (script), DocuSign domains if needed.

## 9) Turbo/Turbo-Cache

- Stripe.js tags include `data-turbo-track="reload"` to avoid stale caches.
- Avoid caching dynamic activation steps.

## 10) Observability & Logging

- Enable structured logs for webhook requests/responses.
- Mask secrets in logs.
- Log DocuSign token/userinfo/envelope error code/message (not raw tokens) for support.

## 11) Security

- HTTPS everywhere; secure cookies; HSTS.
- Rotate all demo keys to production keys.
- Limit org/user access to activation endpoints.

## 12) Final Production Smoke Tests

- Stripe:
  - SetupIntent flow: save a valid card; verify default payment method saved.
  - PaymentIntent: run a cd /Users/hassanali/www/sites/hbs_data_processing && printf "%s" "# Production Readiness Checklist

Use this runbook to promote the activation/billing/compliance stack to production.

## 1) Environment Configuration

Set the following credentials/secrets in production (Rails credentials or ENV):

- Stripe
  - STRIPE_PUBLISHABLE_KEY
  - STRIPE_SECRET_KEY

- DocuSign (Production tenants)
  - DOCUSIGN_INTEGRATION_KEY (production app GUID)
  - DOCUSIGN_USER_ID (API user GUID that grants consent)
  - DOCUSIGN_PRIVATE_KEY_PATH (absolute path on server)
  - DOCUSIGN_BASE_URL=https://www.docusign.net/restapi

- App
  - RAILS_MASTER_KEY
  - REDIS_URL (for Sidekiq)
  - DATABASE_URL

## 2) DocuSign (switching from Demo → Production)

- Create a production DocuSign app; upload the RSA public key that matches the private key file you deploy.
- Add Redirect URIs (must be HTTPS). Example: https://your-domain.com/
- Grant consent once with the production auth host using the API user:
  - https://account.docusign.com/oauth/auth?response_type=code&scope=signature%20impersonation&client_id=INTEGRATION_KEY&redirect_uri=ENCODED_REDIRECT
- Verify the API user GUID matches DOCUSIGN_USER_ID and belongs to the target production account.

Notes:
- OAuth token/consent hosts: account.docusign.com (prod)
- REST API host: www.docusign.net (prod)

## 3) Stripe

- Rotate Stripe keys to production values.
- Ensure \`config/initializers/stripe.rb\` reads from production credentials.
- Webhooks (production endpoint):
  - Expose and configure Stripe webhooks for: checkout.session.completed, setup_intent.succeeded, payment_intent.succeeded (and any additional ones used).
  - Lock down webhook signing secret in credentials.

## 4) Webhooks & Inbound Endpoints

- Allowlist source IPs or protect with signatures where supported.
- Ensure HTTPS termination is in place.
- Double-check route paths match provider console configuration.

## 5) Background Jobs / Scheduling

- Sidekiq configured with REDIS_URL.
- Ensure MonthEndBillingJob is scheduled (via cron/scheduler) to run at month end:
  - Rake task: \`rake billing:run_month_end_charges\`
  - Or use Sidekiq Cron/Heroku Scheduler/OS cron.

## 6) Files & Keys on Host

- Place DocuSign private key file on server (outside repo) and set DOCUSIGN_PRIVATE_KEY_PATH to that file.
- Permissions: \`chmod 600\` on the key file; owned by deploy user.
- Ensure \`config/docusign_private_key.pem\` is NOT committed. \`.gitignore\` already ignores it.

## 7) Compliance Templates

- GSA template lives at \`app/documents/gsa_template.docx\`.
- For BAA, add \`app/documents/baa_template.docx\` and wire a similar renderer.
- Use placeholders like \`{{organization_name}}\`, \`{{owner_name}}\`, \`{{owner_email}}\`, \`{{current_date}}\`.

## 8) Content Security Policy (CSP)

- Allow Stripe.js and DocuSign signing URLs if rendered in-app.
- Example allowances: \`https://js.stripe.com\` (script), DocuSign domains if needed.

## 9) Turbo/Turbo-Cache

- Stripe.js tags include \`data-turbo-track=\"reload\"\` to avoid stale caches.
- Avoid caching dynamic activation steps.

## 10) Observability & Logging

- Enable structured logs for webhook requests/responses.
- Mask secrets in logs.
- Log DocuSign token/userinfo/envelope error code/message (not raw tokens) for support.

## 11) Security

- HTTPS everywhere; secure cookies; HSTS.
- Rotate all demo keys to production keys.
- Limit org/user access to activation endpoints.

## 12) Final Production Smoke Tests

- Stripe:
  - SetupIntent flow: save a valid card; verify default payment method saved.
  - PaymentIntent: run a $1 test charge (or live mode micro-charge) and refund.

- DocuSign:
  - Trigger GSA envelope; verify both signers receive emails.
  - Sign as each user; confirm envelope status transitions to \`completed\`.

- Month-end billing:
  - Run \`rake billing:run_month_end_charges\` in a safe org; verify invoices/charges.

## 13) Rollback Plan

- Ability to disable activation steps via a feature flag/environment toggle.
- Revert to demo keys by swapping credentials and redeploying, if needed.

---

When all checks above pass, you’re production-ready.
" > PRODUCTION_READINESS.md test charge (or live mode micro-charge) and refund.

- DocuSign:
  - Trigger GSA envelope; verify both signers receive emails.
  - Sign as each user; confirm envelope status transitions to `completed`.

- Month-end billing:
  - Run `rake billing:run_month_end_charges` in a safe org; verify invoices/charges.

## 13) Rollback Plan

- Ability to disable activation steps via a feature flag/environment toggle.
- Revert to demo keys by swapping credentials and redeploying, if needed.

---

When all checks above pass, you’re production-ready.
