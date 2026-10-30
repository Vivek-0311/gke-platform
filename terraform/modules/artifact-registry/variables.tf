variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "name" {
  description = "Repository ID."
  type        = string
}

variable "keep_count" {
  description = "How many recent image versions to always keep."
  type        = number
  default     = 10
}

variable "labels" {
  type    = map(string)
  default = {}
}
