#!/usr/bin/env bash
export NAMESPACE=vault

IS_INIT=`kubectl -n $NAMESPACE exec -it vault-0 -- sh -c "vault status | grep Initialized | tr -s ' ' | cut -d ' ' -f2 | tr -d '\n'"`

if [[ $IS_INIT == "true" ]]
then
    echo "Vault is already initialized"
    echo "Exit Setup job.."
    exit 0
fi

# Initialize Vault with five key shares and three key threshold
kubectl exec -n $NAMESPACE vault-0 -- vault operator init -format=json > cluster-keys.json
# Capture the Vault unseal keys and root token
VAULT_ROOT_TOKEN=$(cat cluster-keys.json | jq -r ".root_token")
VAULT_UNSEAL_KEY_1=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[0]")
VAULT_UNSEAL_KEY_2=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[1]")
VAULT_UNSEAL_KEY_3=$(cat cluster-keys.json | jq -r ".unseal_keys_b64[2]")
# Unsealing Vault
kubectl exec -n $NAMESPACE vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY_1
kubectl exec -n $NAMESPACE vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY_2
kubectl exec -n $NAMESPACE vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY_3
# Join raft cluster with vault-0 as leader
kubectl exec -n $NAMESPACE vault-1 -- vault operator raft join http://vault-0.vault-internal:8200
kubectl exec -n $NAMESPACE vault-2 -- vault operator raft join http://vault-0.vault-internal:8200
# Unsealing vault-1, vault-2 pods
kubectl exec -n $NAMESPACE vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY_1
kubectl exec -n $NAMESPACE vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY_2
kubectl exec -n $NAMESPACE vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY_3
kubectl exec -n $NAMESPACE vault-2 -- vault operator unseal $VAULT_UNSEAL_KEY_1
kubectl exec -n $NAMESPACE vault-2 -- vault operator unseal $VAULT_UNSEAL_KEY_2
kubectl exec -n $NAMESPACE vault-2 -- vault operator unseal $VAULT_UNSEAL_KEY_3
# Creating k8s secret containing vault credentials
kubectl create secret generic vault-secret -n vault --from-literal=token=$VAULT_ROOT_TOKEN

# Login to vault
kubectl exec -n $NAMESPACE vault-0 -- vault login $VAULT_ROOT_TOKEN > /dev/null 2>&1

# Enable kv-v2 secrets at the path secret
kubectl exec -n $NAMESPACE vault-0 -- vault secrets enable -path=secret kv-v2
