# Red virtual principal (VPC) - aísla y contiene todos los recursos de red
resource "aws_vpc" "main" {
  # Bloque de direcciones IP ej: 10.0.0.0/16 = 65,536 IPs disponibles
  cidr_block           = var.vpc_cidr
  # Habilita resolución de DNS interna (necesario para que los servicios se encuentren)
  enable_dns_support   = true
  # Asigna nombres DNS a las instancias (ej: ip-10-0-1-5.ec2.internal)
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project}-vpc-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# Puerta de enlace a Internet - permite tráfico hacia/desde internet
resource "aws_internet_gateway" "main" {
  # La VPC a la que pertenece
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-igw-${var.environment}"
    Environment = var.environment
  }
}

# Subred pública - recursos accesibles desde internet (ALB, NAT, etc.)
resource "aws_subnet" "public" {
  # Crea tantas subredes como CIDRs definidos en variables
  count             = length(var.public_subnet_cidrs)
  # VPC a la que pertenece
  vpc_id            = aws_vpc.main.id
  # Bloque de IPs para esta subred ej: 10.0.101.0/24 = 256 IPs
  cidr_block        = var.public_subnet_cidrs[count.index]
  # Zona de disponibilidad (donde vive físicamente)
  availability_zone = var.azs[count.index]

  # Asigna IP pública automática a todo lo que se levante acá
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project}-public-${var.azs[count.index]}-${var.environment}"
    Environment = var.environment
    Type        = "public"
  }
}

# Subred privada - recursos SIN acceso directo a internet (RDS, ECS tasks)
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name        = "${var.project}-private-${var.azs[count.index]}-${var.environment}"
    Environment = var.environment
    Type        = "private"
  }
}

# Tabla de rutas para subredes públicas - define cómo sale el tráfico
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Regla: todo el tráfico a internet (0.0.0.0/0) sale por el Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project}-public-rt-${var.environment}"
    Environment = var.environment
  }
}

# Asocia cada subred pública con la tabla de rutas públicas
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


