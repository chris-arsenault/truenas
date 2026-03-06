resource "truenas_dataset" "docker" {
  pool      = var.pool_name
  name      = "docker"
  comments  = "Docker volumes and data"
  sync      = "standard"
  atime     = "off"
  exec      = "on"
  snap_dir  = "hidden"
  copies    = 1
  quota     = 0
  readonly  = "off"
  recordsize = "128K"
}

resource "truenas_dataset" "sonarqube" {
  pool      = var.pool_name
  name      = "${truenas_dataset.docker.name}/sonarqube"
  comments  = "SonarQube data"
  sync      = "standard"
  atime     = "off"
  copies    = 1
  quota     = 0
  readonly  = "off"
  recordsize = "128K"
}

resource "truenas_dataset" "sonarqube_db" {
  pool      = var.pool_name
  name      = "${truenas_dataset.docker.name}/sonarqube-db"
  comments  = "SonarQube PostgreSQL data"
  sync      = "always"
  atime     = "off"
  copies    = 1
  quota     = 0
  readonly  = "off"
  recordsize = "16K"
}
