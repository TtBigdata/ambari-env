

PKG="/root/.m2/repository/com/github/eirslett/yarn/1.22.22/yarn-1.22.22./yarn-v1.22.22.tar.gz"
mkdir -p "$(dirname "$PKG")" && wget -O "$PKG" "https://ghfast.top/https://github.com/yarnpkg/yarn/releases/download/v1.22.22/yarn-v1.22.22.tar.gz"
T=$(mktemp -d); tar -xzf "$PKG" -C "$T" && mv "$T"/yarn-* "$T"/dist && tar -czf "$PKG" -C "$T" dist


export JAVA_HOME=/opt/modules/bisheng-jdk-17.0.17
export PATH=$JAVA_HOME/bin:$PATH

java -version

cd /opt/modules/ambari/contrib/views
mvn clean install -DskipTests


cd /opt/modules/ambari

mvn package install \
rpm:rpm \
-Drat.skip=true \
-Dcheckstyle.skip=true \
-Dspotbugs.skip=true \
-Pkylin10-aarch64 \
-Dttbigdata.release.version=3.0.0 \
-DskipTests


find . -iname '*.rpm' -exec cp -rv {} /data/ambari \;