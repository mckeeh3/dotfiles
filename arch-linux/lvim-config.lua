-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny
--

vim.opt.relativenumber = true
vim.opt.guifont = "Azeret Mono"
vim.opt.wrap = true

-- lvim.colorscheme = "tokyonight-night"
-- lvim.colorscheme = "material"
lvim.colorscheme = "carbonfox"
-- vim.g.material_style = "deep ocean"

lvim.format_on_save = true
lvim.reload_config_on_save = true

lvim.plugins = {
  { "folke/tokyonight.nvim" },
  { "lunarvim/colorschemes" },
  { "marko-cerovac/material.nvim" },
  { "EdenEast/nightfox.nvim" },
}
