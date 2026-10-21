enum SftpSortMode { name, modified, size, type }

extension SftpSortModeLabel on SftpSortMode {
  String get label => switch (this) {
    SftpSortMode.name => 'Name',
    SftpSortMode.modified => 'Modified',
    SftpSortMode.size => 'Size',
    SftpSortMode.type => 'Type',
  };
}
