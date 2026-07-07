-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

-- True color in tmux
if vim.env.TMUX then
  vim.g.termguicolors = true
end
