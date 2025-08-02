# Step 1: Setup master node
resource "null_resource" "master_setup_remote" {
  provisioner "local-exec" {
    command = <<EOT
scp -o StrictHostKeyChecking=no -i ${var.private_key_path} ${var.master_script_path} ${var.ssh_user}@${var.master_ip}:${var.master_script_path}
ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ${var.ssh_user}@${var.master_ip} "sudo bash ${var.master_script_path}"
EOT
  }
}

# Step 2: Setup worker node
resource "null_resource" "worker_setup" {
  provisioner "local-exec" {
    command = <<EOT
scp -o StrictHostKeyChecking=no -i ${var.private_key_path} ${var.worker_script_path} ${var.ssh_user}@${var.worker_ip}:${var.worker_script_path}
ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ${var.ssh_user}@${var.worker_ip} "sudo bash ${var.worker_script_path}"
EOT
  }
}

# Step 3: Fetch join command from master and write to join.sh, then copy to worker
resource "null_resource" "fetch_and_copy_join_command" {
  depends_on = [null_resource.master_setup_remote, null_resource.worker_setup]

  provisioner "local-exec" {
    command = <<EOT
JOIN_CMD=$(ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ${var.ssh_user}@${var.master_ip} "sudo kubeadm token create --print-join-command")
echo "#!/bin/bash" > join.sh
echo "$JOIN_CMD" >> join.sh
chmod +x join.sh
scp -o StrictHostKeyChecking=no -i ${var.private_key_path} join.sh ${var.ssh_user}@${var.worker_ip}:/tmp/join.sh
EOT
  }
}

# Step 4: Run join.sh on worker node
resource "null_resource" "run_join_on_worker" {
  depends_on = [null_resource.fetch_and_copy_join_command]

  provisioner "local-exec" {
    command = <<EOT
ssh -o StrictHostKeyChecking=no -i ${var.private_key_path} ${var.ssh_user}@${var.worker_ip} "sudo bash /tmp/join.sh"
EOT
  }
}
