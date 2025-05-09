CREDFILE=key-file.json
SVCACCOUNT="${SERVICE_ACCOUNT}"

terraform plan  --var project_id=${PROJECT} --var credential_file_path=${CREDFILE} --var service_account=${SVCACCOUNT} --var namespace=coder
coder templates push -y --var project_id=${PROJECT} --var credential_file_path=${CREDFILE} --var service_account=${SVCACCOUNT} --var namespace=coder
