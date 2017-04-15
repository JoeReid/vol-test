#!/usr/bin/env bats

load test_helper

@test "Create replicated volume using driver ($driver)" {
  run $prefix2 docker volume create --driver $driver $createopts --opt storageos.feature.replicas=1 repvol1
  assert_success
}

@test "Confirm volume is created (volume ls) using driver ($driver)" {
  run $prefix2 docker volume ls
  assert_line --partial "repvol1"
}

@test "Confirm volume has 1 replica using storageos cli" {
  run $prefix2 storageos $cliopts volume inspect default/repvol1
  assert_line --partial "\"storageos.feature.replicas\": \"1\"",
}

@test "Start a container and mount the volume on node 2" {
  run $prefix2 docker run -it -d --name mounter -v repvol1:/data ubuntu /bin/bash
  assert_success
}

@test "Create a binary file" {
  run $prefix2 -t docker exec -it 'mounter dd if=/dev/urandom of=/data/random bs=10M count=1'
  assert_output --partial "10 M"
}

@test "Get a checksum for that binary file" {
  run $prefix2 -t 'docker exec -it mounter /bin/bash -c "md5sum /data/random > /data/checksum"'
  assert_success
}

@test "Confirm checksum on node 2" {
  run $prefix2 -t docker exec -it mounter md5sum --check /data/checksum
  assert_success
}

@test "Stop container on node 2" {
  run $prefix2 docker stop mounter
  assert_success
}

@test "Destroy container on node 2" {
  run $prefix2 docker rm mounter
  assert_success
}

@test "Stop storageos on node 2" {
  run $prefix2 docker plugin disable -f $driver
  assert_success
}

@test "Wait 60 seconds" {
  sleep 60
  assert_success
}

@test "Confirm checksum on node 1" {
  run $prefix -t docker run -it --rm -v repvol1:/data ubuntu md5sum --check /data/checksum
  assert_success
}

@test "Re-start storageos on node 2" {
  run $prefix2 docker plugin enable $driver
  assert_success
}

# @test "Delete volume using storageos cli" {
#   run $prefix2 storageos $cliopts volume rm default/repvol1
#   assert_success
# }
