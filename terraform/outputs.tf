output "nodes" {
  description = "Docker container names by service role."
  value       = { for role, container in docker_container.nodes : role => container.name }
}

output "ansible_inventory" {
  description = "Path to the generated Ansible inventory file."
  value       = local_file.ansible_inventory.filename
}
