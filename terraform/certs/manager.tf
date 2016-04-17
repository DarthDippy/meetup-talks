resource "tls_private_key" "swarm_manager_key" {
    algorithm = "RSA"

    lifecycle {
        create_before_destroy = true
    }
}

resource "tls_cert_request" "swarm_manager_csr" {
    key_algorithm   = "${tls_private_key.ca_key.algorithm}"
    private_key_pem = "${tls_private_key.swarm_manager_key.private_key_pem}"

    dns_names = ["*.tripler.tech", "*.compute-1.amazonaws.com"]

    subject {
        common_name = "manager"
    }
}

resource "tls_locally_signed_cert" "swarm_manager_cert" {
    ca_key_algorithm   = "${tls_private_key.ca_key.algorithm}"
    ca_cert_pem        = "${tls_self_signed_cert.ca_cert.cert_pem}"
    ca_private_key_pem = "${tls_private_key.ca_key.private_key_pem}"
    cert_request_pem   = "${tls_cert_request.swarm_manager_csr.cert_request_pem }"

    allowed_uses          = ["any_extended", "client_auth"]
    validity_period_hours = 12
}

resource "null_resource" "generate_swarm_manager_certs" {
    triggers = {
        ca_cert            = "${tls_self_signed_cert.ca_cert.cert_pem}"
        swarm_manager_key  = "${tls_private_key.swarm_manager_key.private_key_pem}"
        swarm_manager_cert = "${tls_locally_signed_cert.swarm_manager_cert.cert_pem}"
    }

    provisioner "local-exec" {
        command = <<EOF
echo "${tls_self_signed_cert.ca_cert.cert_pem}"               > ${path.module}/manager/ca.pem
echo "${tls_private_key.swarm_manager_key.private_key_pem}"   > ${path.module}/manager/key.pem
echo "${tls_locally_signed_cert.swarm_manager_cert.cert_pem}" > ${path.module}/manager/cert.pem
EOF
    }
}

output "swarm_manager_key_pem" {
    value = "${base64encode(tls_private_key.swarm_manager_key.private_key_pem)}"
}

output "swarm_manager_cert_pem" {
    value = "${base64encode(tls_locally_signed_cert.swarm_manager_cert.cert_pem)}"
}
