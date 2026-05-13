#!/bin/bash
# Usage: ./import_dict.sh path/to/dict.txt

if [ -z "$1" ]; then
    echo "Usage: $0 <dict_file>"
    exit 1
fi

DB_PATH="$HOME/Library/Application Support/WubiMac/wubi86.db"
mkdir -p "$(dirname "$DB_PATH")"

# 这里可以利用 swift 脚本来调用 WubiDictBuilder
swift -I .build/debug -WubiEngine scripts/make_sample_db.swift "$DB_PATH" # 简化处理
