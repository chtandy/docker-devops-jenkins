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
### 第一次啟動
docker-compose up -d --build

### jenkins plugin 注意事項
- Node and Label parameter
  - 選項在參數化建置內
  - `不能使用`限制專案執行節點選項
### 沒有權限的方式
```
mkdir -p ./data/jenkins_home ./data/data && chmod 777 ./data/jenkins_home && umask 0002 && \
touch ./data/jenkins_home/copy_reference_file.log && chmod 777 ./data/jenkins_home/copy_reference_file.log
```
