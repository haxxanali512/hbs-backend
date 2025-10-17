# DocuSign Production Preparation

Use this guide to move DocuSign from Demo to Production for this app.

## 1) Create Production App (DocuSign Admin)
- Environment: Production
- App name: HBS (Prod)
- Auth: JWT with RSA key pair
- Upload the RSA public key that matches your private key file
- Add Redirect URI(s) (HTTPS only), e.g. https://your-domain.com/

## 2) Credentials to configure
Set via Rails credentials or ENV:
- DOCUSIGN_INTEGRATION_KEY: Production Integration Key (client_id)
- DOCUSIGN_USER_ID: API user GUID (the user granting consent)
- DOCUSIGN_PRIVATE_KEY_PATH: Absolute path to the private key on the server
- DOCUSIGN_BASE_URL: https://www.docusign.net/restapi

Private key file on server:
- Place file outside the repo, readable by app user only
- chmod 600 /path/to/private_key.pem

## 3) One‑time User Consent (Production)
While logged in as the API user, open:
https://account.docusign.com/oauth/auth?response_type=code&scope=signature%20impersonation&client_id=INTEGRATION_KEY&redirect_uri=ENCODED_REDIRECT

Notes:
- The  must exactly match one of the app’s Redirect URIs
- After acceptance, consent is recorded per user × app in that environment

## 4) App-side configuration expectations
- OAuth token host: account.docusign.com (handled in service)
- REST API host: www.docusign.net (service forces correct base path after userinfo)
- We automatically resolve the default account via /oauth/userinfo

## 5) Document templates
Local path(s):
- app/documents/gsa_template.docx (already wired)
- app/documents/baa_template.docx (optional—add to enable)

Placeholders supported (in DOCX text):
- {{organization_name}}
- {{owner_name}}
- {{owner_email}}
- {{current_date}}
- (Add more as needed, e.g. {{client_email}} — see below)

To add a new field (example: client email):
- Put {{client_email}} in the DOCX where shown in red
- Update replacement map in 
  - e.g., {{client_email}} => organization.owner_email (or your source)

## 6) Recipients (signers)
Current behavior for GSA:
- Signer 1: Organization owner (from organization.owner.email or organization.owner_email)
- Signer 2: steven@holisticbusinesssolution.com (DocuSign account owner)
- routing_order: 1 for both (parallel). Set 1/2 for sequential if required

## 7) Production validation (smoke tests)
- Trigger a GSA envelope from the compliance page
- Verify both signers receive emails from DocuSign (prod)
- Sign as each user → ensure envelope status becomes 

## 8) Troubleshooting
- 401 consent_required → open the consent URL above as API user
- 401 on envelopes → ensure API user GUID matches account; base host is www.docusign.net
- 400 Bad Request → check logs for errorCode/message (invalid tabs, empty document, etc.)

## 9) Rollback
- Revert to Demo by swapping credentials to demo keys and redeploying

This completes DocuSign production preparation for this application.