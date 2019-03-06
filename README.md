# 立法院爬蟲

## 緣起

由於原先g0v的[twly_crawler](https://github.com/g0v/twly_crawler)與[twlyparser](https://github.com/g0v/twlyparser)有點混亂，也難以使用，因此嘗試重新復刻ruby版爬蟲，以產生mly-#{ad}.json，供大家使用。

目前有些uid需自行維護，因此若未來有新版立委，請修改[additional/additionals.json](additional/additionals.json)檔案以新增uid。

## 安裝

請安裝以下gem以執行程式：

```
gem install bundler
bundle install
```

## 說明

執行順序與說明：

### 爬取立法院資料

```
./ly_info_crawler.rb
```

立法院網頁圖片如下，若有修改，表示本爬蟲已無法使用：

[第三屆立委列表](page_example/ly_info_ad_3.png)
[第九屆立委列表](page_example/ly_info_ad_9.png)
[立委個人頁](page_example/ly_info_profile.png)

### 爬取國會圖書館資料

```
./npl_ly_crawler.rb
```

國會圖書館網頁圖片如下，若有修改，表示本爬蟲已無法使用：

[立委列表](page_example/npl_ly_ad.png)
[立委個人頁](page_example/npl_ly_profile.png)

### 產生立法委員UID

```
./legislators_uid_generator.rb
```

### 彙整立法院與國會圖書館資料

```
./merge.rb
```

### 產生mly檔案

```
./mly_generator.rb #{ad}
```

## LICENSE

[MIT](LICENSE.md)


