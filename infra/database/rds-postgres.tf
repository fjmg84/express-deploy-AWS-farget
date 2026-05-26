# Grupo de parámetros de PostgreSQL (configuraciones extra del motor)
resource "aws_db_parameter_group" "postgres" {
  # Nombre único del grupo de parámetros ej: floci-pg-params-dev
  name        = "${var.project}-pg-params-${var.environment}"
  # Familia del motor de BD (postgres16 = PostgreSQL 16.x)
  family      = "postgres16"
  # Descripción visible en AWS
  description = "Parameter group para PostgreSQL 16"

  # Activa logs de conexiones entrantes
  parameter {
    name  = "log_connections"
    value = "1"
  }

  # Activa logs de desconexiones
  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  # Etiquetas para identificar el recurso
  tags = {
    Name        = "${var.project}-pg-params-${var.environment}"
    Environment = var.environment
  }
}

# La instancia de base de datos PostgreSQL en sí
resource "aws_db_instance" "postgres" {
  # Nombre visible de la BD ej: floci-pg-dev
  identifier = "${var.project}-pg-${var.environment}"

  # Motor de base de datos y versión
  engine         = "postgres"
  engine_version = "16.3"
  # Tamaño de la instancia (CPU/RAM) ej: db.t3.medium
  instance_class = var.db_instance_class

  # Espacio en disco en GB
  allocated_storage     = var.db_allocated_storage
  # Tipo de disco (gp3 es el estándar actual)
  storage_type          = "gp3"
  storage_encrypted     = true
  # Actualiza automáticamente a versiones menores (16.3 → 16.4)
  auto_minor_version_upgrade = true

  # Nombre de la base de datos ej: floci_dev
  db_name  = "${var.project}_${var.environment}"
  # Usuario administrador
  username = var.db_username
  # Contraseña del administrador
  password = var.db_password

  # Grupos de seguridad (firewall) que permiten tráfico hacia la BD
  vpc_security_group_ids = [var.rds_security_group_id]
  # Grupo de parámetros definido arriba (logs de conexiones)
  parameter_group_name   = aws_db_parameter_group.postgres.name

  # Días que se guardan los backups (7 en prod, 1 en dev)
  backup_retention_period = var.environment == "prod" ? 7 : 1
  # Ventana horaria para backups automáticos (3:00-4:00 AM UTC)
  backup_window           = "03:00-04:00"
  # Ventana horaria para mantenimiento (domingo 4-5 AM UTC)
  maintenance_window      = "sun:04:00-sun:05:00"

  # Alta disponibilidad (solo en prod: replica en otra zona)
  multi_az               = var.environment == "prod"
  # Evita borrar la BD accidentalmente (solo en prod)
  deletion_protection    = var.environment == "prod"
  # Saltea el snapshot final al destruir (solo en dev, para no dejar snapshots huérfanos)
  skip_final_snapshot    = var.environment != "prod"
  # Copia las etiquetas (tags) a los snapshots de backup
  copy_tags_to_snapshot  = true

  # Etiquetas para identificar la BD
  tags = {
    Name        = "${var.project}-pg-${var.environment}"
    Environment = var.environment
  }

}
