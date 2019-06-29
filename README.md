### 環境注意
- 如果是MAC,則 volumes 中有關docker的部分要改成
```
- /usr/local/bin/docker:/usr/bin/docker
```
- 如果是linux ,則 volumes 中有關docker的部分要改成
```
- /usr/bin/docker:/usr/bin/docker
 ```
### docker 啟動前,先執行
```
mkdir -p ./data/jenkins_home ./data/data && umask 0002 && \
touch ./data/jenkins_home/copy_reference_file.log && chmod +rw ./data/jenkins_home/copy_reference_file.log
```
