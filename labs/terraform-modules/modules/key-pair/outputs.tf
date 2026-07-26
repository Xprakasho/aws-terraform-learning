output "key_name" {

  description = "Key Pair Name"

  value = aws_key_pair.this.key_name

}

output "key_pair_id" {

  description = "Key Pair ID"

  value = aws_key_pair.this.id

}