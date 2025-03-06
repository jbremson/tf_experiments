terraform {
  backend "remote" {
    organization = "JoelCo"

    workspaces {
      name = "tf_experiments"
    }
  }
}