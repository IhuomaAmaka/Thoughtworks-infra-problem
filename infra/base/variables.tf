variable "prefix" {
  type = string
}

variable "repository_names" {
  description = "List of repository names"
  type        = list(string)
  default     = ["quotes", "newsfeed", "front-end"]
}

variable "region" {
  default = "eu-west-1"
}