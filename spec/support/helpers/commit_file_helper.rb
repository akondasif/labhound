module CommitFileHelper
  def build_commit_file(filename:, content: 'code')
    line = double(
      'Line',
      changed?: true,
      content: 'blah',
      number: 1,
      patch_position: 2
    )
    double(
      'CommitFile',
      content: content,
      filename: filename,
      line_at: line,
      sha: 'abc123',
      patch: 'patch',
      pull_request_number: 123
    )
  end
end
