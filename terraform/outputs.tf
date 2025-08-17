# Public IP of the mail server (Elastic IP)
output "mail_server_public_ip" {
  description = "The static public IP address of the CourierX mail server"
  value       = aws_eip.mail_server_ip.public_ip
}

# Instance information
output "mail_server_instance_id" {
  description = "The EC2 instance ID of the mail server"
  value       = aws_instance.mail_server.id
}

# Comprehensive DNS setup instructions
output "dns_records_to_create" {
  description = "Complete DNS configuration instructions for your external DNS provider (Hostinger)"
  value = <<-EOT
  
  ================================================================
  DNS CONFIGURATION REQUIRED IN HOSTINGER
  ================================================================
  
  Create the following DNS records in your Hostinger DNS management:
  
  1. A Record (Mail Server):
     Name: mail
     Type: A
     Value: ${aws_eip.mail_server_ip.public_ip}
     TTL: 300 (or Auto)
  
  2. MX Record (Mail Exchange):
     Name: @ (or leave empty for root domain)
     Type: MX
     Value: mail.${var.domain_name}
     Priority: 10
     TTL: 300 (or Auto)
  
  3. SPF Record (Sender Policy Framework):
     Name: @ (or leave empty for root domain)
     Type: TXT
     Value: "v=spf1 mx ~all"
     TTL: 300 (or Auto)
  
  4. DMARC Record (Domain-based Message Authentication):
     Name: _dmarc
     Type: TXT
     Value: "v=DMARC1; p=none; rua=mailto:admin@${var.domain_name}"
     TTL: 300 (or Auto)
  
  5. DKIM Record (DomainKeys Identified Mail):
     Name: mail._domainkey
     Type: TXT
     Value: <TO BE RETRIEVED FROM SERVER>
     TTL: 300 (or Auto)
  
  ================================================================
  IMPORTANT: DKIM PUBLIC KEY RETRIEVAL
  ================================================================
  
  After the server finishes setup (5-10 minutes), SSH to retrieve 
  the DKIM public key:
  
  ssh -i your-private-key ubuntu@${aws_eip.mail_server_ip.public_ip}
  sudo cat /etc/opendkim_public_key.txt
  
  Copy the content between the quotes and use it as the DKIM TXT record value.
  
  ================================================================
  VERIFICATION STEPS
  ================================================================
  
  After DNS propagation (up to 24 hours), verify:
  1. MX lookup: dig MX ${var.domain_name}
  2. SPF record: dig TXT ${var.domain_name}
  3. DKIM record: dig TXT mail._domainkey.${var.domain_name}
  4. DMARC record: dig TXT _dmarc.${var.domain_name}
  
  ================================================================
  
  EOT
}

# Mail server connection details
output "mail_server_connection_info" {
  description = "Connection information for the mail server"
  value = {
    hostname = "mail.${var.domain_name}"
    smtp_port = 587
    imap_port = 993
    public_ip = aws_eip.mail_server_ip.public_ip
  }
}

# Setup summary
output "deployment_summary" {
  description = "Deployment summary and next steps"
  value = <<-EOT
  
  ================================================================
  COURIERX DEPLOYMENT SUMMARY
  ================================================================
  
  ✅ Infrastructure Deployed Successfully!
  
  Server Details:
  - Instance ID: ${aws_instance.mail_server.id}
  - Public IP: ${aws_eip.mail_server_ip.public_ip}
  - Hostname: mail.${var.domain_name}
  - Region: ${var.aws_region}
  
  Mail Accounts Created:
  - noreply@${var.domain_name} (SMTP authentication)
  - support@${var.domain_name} (forwards to ${var.forward_to})
  
  Next Steps:
  1. Wait 5-10 minutes for server setup to complete
  2. Configure DNS records as shown in 'dns_records_to_create' output
  3. Retrieve DKIM key from server
  4. Test email functionality
  
  Monitoring:
  - Setup logs: ssh ubuntu@${aws_eip.mail_server_ip.public_ip} 'sudo tail -f /var/log/courierx-setup.log'
  - Setup summary: ssh ubuntu@${aws_eip.mail_server_ip.public_ip} 'sudo cat /root/courierx-setup-summary.txt'
  
  ================================================================
  
  EOT
}