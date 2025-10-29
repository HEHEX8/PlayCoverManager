PlayCover インストール検証スクリプト集
===========================================

これらのスクリプトを使って、PlayCoverのIPAインストール動作を詳細に調査します。

## 📋 準備

1. スクリプトに実行権限を付与:
   chmod +x *.sh

2. ログディレクトリが自動作成されます:
   ~/playcover_verification_logs/

## 🔬 スクリプト一覧

### 1_trace_filesystem_changes.sh
- fswatch でファイルシステム変更を追跡
- どのファイルがいつ作成/更新されるかを記録
- 実行後、PlayCoverでIPAインストール → Enter押下

### 2_monitor_cpu_memory.sh  
- CPU使用率とメモリ使用量を1秒ごとに記録
- インストール処理の負荷を測定
- 実行後、PlayCoverでIPAインストール → Ctrl+C で停止

### 3_monitor_file_access.sh
- lsof で設定ファイルへのアクセスを監視
- PlayCoverがいつまでファイルを開いているか記録
- 実行後、PlayCoverでIPAインストール → Ctrl+C で停止

### 4_track_mtime_changes.sh
- 設定ファイルのmtime変更を詳細追跡
- 更新回数と間隔を記録
- Bundle ID入力が必要
- 実行後、PlayCoverでIPAインストール → Ctrl+C で停止

### 5_comprehensive_monitor.sh （推奨）
- 上記すべてを統合した包括的監視
- Bundle IDとIPAサイズ入力が必要
- 実行後、PlayCoverでIPAインストール → Enter押下

## 🎯 推奨実行順序

1. まず 5_comprehensive_monitor.sh で全体データ収集
2. 必要に応じて個別スクリプトで詳細調査

## 📊 検証対象

各スクリプトを以下の両方で実行してください:
- 小容量IPA（180MB程度）
- 大容量IPA（2-3GB）

## 📤 結果の送付

以下のディレクトリをtar.gzで圧縮して送付:
~/playcover_verification_logs/

コマンド例:
cd ~
tar -czf playcover_logs_$(date +%Y%m%d).tar.gz playcover_verification_logs/
