# `.docs` - 仕様・調査資料

このディレクトリには`chmod-for-windows`の実装判断に必要な背景仕様をまとめます。

## ドキュメント

- [`icacls.md`](icacls.md)  
  Windows Security Descriptor / DACL / SACL / ACE / 継承 / Owner / MIC / UAC / 特権 / File System差と、`icacls.exe`の仕様・注意点。

- [`chmod.md`](chmod.md)  
  POSIX / GNU coreutils `chmod`のfile mode、numeric/symbolic MODE、umask、`X`、special bits、recursive、symlink、GNU拡張等とWindows版への対応。

## 読み方

実装変更時は片方だけではなく両方を参照してください。

```text
GNU/POSIX chmod semantics
        ↓
どの意図を再現したいか
        ↓
Windows Security Descriptor / ACL semantics
        ↓
安全で予測可能な近似を選択
```

このプロジェクトは「GNU chmodをWindowsへ完全移植」するものではありません。

Windows ACLで再現できないものは無理に同名実装せず、近似・非互換・独自仕様であることを明記します。

## 情報源

仕様判断では原則:

1. Microsoft / GNU / The Open Group等の一次資料
2. 対象versionの実装/source/実行ファイルhelp
3. 実機検証
4. 国内外のコミュニティ資料

の順で優先します。

Webドキュメントと実装が食い違う場合は、その差異自体を記録します。

## 未検証事項

`.docs`には未検証事項も意図的に残します。

未検証事項を推測で「仕様」に昇格させず、Windows version / filesystem / local・SMB / symlink・reparse point等を分けてテストしてください。

開発ルール全体はリポジトリルートの[`AGENTS.md`](../AGENTS.md)を参照してください。
