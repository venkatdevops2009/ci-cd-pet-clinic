terraform {
  backend "s3" {
    bucket       = "petclinic1805"
    key          = "ci-cd-jenkins-tf-state"
    region       = "us-east-1"
    use_lockfile = true
  }
}