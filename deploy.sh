CREDFILE=key-file.json
SVCACCOUNT="720523497747-compute@developer.gserviceaccount.com"

terraform plan  --var project_id=${PROJECT} --var credential_file_path=${CREDFILE} --var service_account=${SVCACCOUNT} --var namespace=coder
coder templates push -y --var project_id=${PROJECT} --var credential_file_path=${CREDFILE} --var service_account=${SVCACCOUNT} --var namespace=coder
