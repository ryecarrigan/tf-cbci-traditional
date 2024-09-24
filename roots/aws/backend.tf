terraform {
  backend "s3" {
    bucket = "rcarrigan-tfstate"
    key    = "tf-cbci-traditional/ci/terraform.tfstate"
  }
}
