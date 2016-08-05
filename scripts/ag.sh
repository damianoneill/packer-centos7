pushd /tmp
git clone git://github.com/ggreer/the_silver_searcher.git
yum -y install pcre-devel xz-devel automake
cd the_silver_searcher
./build.sh
make install
cd ..
rm -rf the_silver_searcher
popd
