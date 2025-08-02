# SSH username for accessing all nodes
variable "ssh_user" {
  description = "Default SSH user for remote login"
  default     = "your_ssh_username"
}

# Path to your private SSH key
variable "private_key_path" {
  description = "Path to the SSH private key for accessing nodes"
  default     = "/home/your_ssh_username/.ssh/id_rsa"
}

# IP address of the Kubernetes master node
variable "master_ip" {
  description = "Master node IP address"
  default     = "XXX.XXX.XXX.XXX"
}

# IP address of the Kubernetes worker node
variable "worker_ip" {
  description = "Worker node IP address"
  default     = "XXX.XXX.XXX.XXX"
}

# Full path to the master node setup script
variable "master_script_path" {
  description = "Full path to master_node.sh"
  default     = "/home/your_ssh_username/master_node.sh"
}

# Full path to the worker node setup script
variable "worker_script_path" {
  description = "Full path to worker_node.sh"
  default     = "/home/your_ssh_username/worker_node.sh"
}
