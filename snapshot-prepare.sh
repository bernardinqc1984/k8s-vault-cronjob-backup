#!/usr/bin/env bash
export NAMESPACE=vault

kubectl exec -n $NAMESPACE vault-0 -- vault auth enable approle

kubectl exec -n $NAMESPACE -i vault-0 -- vault policy write snapshot - << EOF
path "sys/storage/raft/snapshot" {
   capabilities = ["read"]
}
EOF

kubectl exec -n $NAMESPACE vault-0 -- vault write auth/approle/role/snapshot-agent token_ttl=2h token_policies=snapshot

VAULT_APPROLE_ROLE_ID=$(kubectl exec -n $NAMESPACE vault-0 -- vault read auth/approle/role/snapshot-agent/role-id -format=json | jq -r .data.role_id)
VAULT_APPROLE_SECRET_ID=$(kubectl exec -n $NAMESPACE vault-0 -- vault write -f auth/approle/role/snapshot-agent/secret-id -format=json | jq -r .data.secret_id)

kubectl create secret generic vault-snapshot-agent-token -n vault --from-literal=VAULT_APPROLE_ROLE_ID=$VAULT_APPROLE_ROLE_ID --from-literal=VAULT_APPROLE_SECRET_ID=$VAULT_APPROLE_SECRET_ID 
