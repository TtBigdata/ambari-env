#!/bin/bash


rm -rf /var/lib/mysql/*

mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
