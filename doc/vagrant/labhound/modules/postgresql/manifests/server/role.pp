# Define for creating a database role. See README.md for more information
define postgresql::server::role(
  $password_hash    = false,
  $createdb         = false,
  $createrole       = false,
  $db               = $postgresql::server::default_database,
  $port             = $postgresql::server::port,
  $login            = true,
  $inherit          = true,
  $superuser        = false,
  $replication      = false,
  $connection_limit = '-1',
  $username         = $title
) {
  $psql_user  = $postgresql::server::user
  $psql_group = $postgresql::server::group
  $psql_path  = $postgresql::server::psql_path
  $version    = $postgresql::server::_version

  $login_sql       = $login       ? { true => 'LOGIN',       default => 'NOLOGIN' }
  $inherit_sql     = $inherit     ? { true => 'INHERIT',     default => 'NOINHERIT' }
  $createrole_sql  = $createrole  ? { true => 'CREATEROLE',  default => 'NOCREATEROLE' }
  $createdb_sql    = $createdb    ? { true => 'CREATEDB',    default => 'NOCREATEDB' }
  $superuser_sql   = $superuser   ? { true => 'SUPERUSER',   default => 'NOSUPERUSER' }
  $replication_sql = $replication ? { true => 'REPLICATION', default => '' }
  if ($password_hash != false) {
    $environment  = "NEWPGPASSWD=${password_hash}"
    $password_sql = "ENCRYPTED PASSWORD '\$NEWPGPASSWD'"
  } else {
    $password_sql = undef
    $environment  = []
  }

  Postgresql_psql {
    db         => $db,
    port       => $port,
    psql_user  => $psql_user,
    psql_group => $psql_group,
    psql_path  => $psql_path,
    require    => [
      Postgresql_psql["CREATE ROLE ${username} ENCRYPTED PASSWORD ****"],
      Class['postgresql::server'],
    ],
  }

  postgresql_psql { "CREATE ROLE ${username} ENCRYPTED PASSWORD ****":
    command     => "CREATE ROLE \"${username}\" ${password_sql} ${login_sql} ${createrole_sql} ${createdb_sql} ${superuser_sql} ${replication_sql} CONNECTION LIMIT ${connection_limit}",
    unless      => "SELECT rolname FROM pg_roles WHERE rolname='${username}'",
    environment => $environment,
    require     => Class['Postgresql::Server'],
  }

  postgresql_psql {"ALTER ROLE \"${username}\" ${superuser_sql}":
    unless => "SELECT rolname FROM pg_roles WHERE rolname='${username}' and rolsuper=${superuser}",
  }

  postgresql_psql {"ALTER ROLE \"${username}\" ${createdb_sql}":
    unless => "SELECT rolname FROM pg_roles WHERE rolname='${username}' and rolcreatedb=${createdb}",
  }

  postgresql_psql {"ALTER ROLE \"${username}\" ${createrole_sql}":
    unless => "SELECT rolname FROM pg_roles WHERE rolname='${username}' and rolcreaterole=${createrole}",
  }

  postgresql_psql {"ALTER ROLE \"${username}\" ${login_sql}":
    unless => "SELECT rolname FROM pg_roles WHERE rolname='${username}' and rolcanlogin=${login}",
  }

  postgresql_psql {"ALTER ROLE \"${username}\" ${inherit_sql}":
    unless => "SELECT rolname FROM pg_roles WHERE rolname='${username}' and rolinherit=${inherit}",
  }

  if(versioncmp($version, '9.1') >= 0) {
    if $replication_sql == '' {
      postgresql_psql {"ALTER ROLE \"${username}\" NOREPLICATION":
        unless => "SELECT rolname FROM pg_roles WHERE rolname='${username}' and rolreplication=${replication}",
      }
    } else {
      postgresql_psql {"ALTER ROLE \"${username}\" ${replication_sql}":
        unless => "SELECT rolname FROM pg_roles WHERE rolname='${username}' and rolreplication=${replication}",
      }
    }
  }

  postgresql_psql {"ALTER ROLE \"${username}\" CONNECTION LIMIT ${connection_limit}":
    unless => "SELECT rolname FROM pg_roles WHERE rolname='${username}' and rolconnlimit=${connection_limit}",
  }

  if $password_hash {
    if($password_hash =~ /^md5.+/) {
      $pwd_hash_sql = $password_hash
    } else {
      $pwd_md5 = md5("${password_hash}${username}")
      $pwd_hash_sql = "md5${pwd_md5}"
    }
    postgresql_psql { "ALTER ROLE ${username} ENCRYPTED PASSWORD ****":
      command     => "ALTER ROLE \"${username}\" ${password_sql}",
      unless      => "SELECT usename FROM pg_shadow WHERE usename='${username}' and passwd='${pwd_hash_sql}'",
      environment => $environment,
    }
  }
}
