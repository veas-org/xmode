# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@tiptap/core", to: "https://esm.sh/@tiptap/core@2.11.7"
pin "@tiptap/starter-kit", to: "https://esm.sh/@tiptap/starter-kit@2.11.7"
pin "@tiptap/extension-link", to: "https://esm.sh/@tiptap/extension-link@2.11.7"
pin "@tiptap/extension-placeholder", to: "https://esm.sh/@tiptap/extension-placeholder@2.11.7"
pin "marked", to: "https://esm.sh/marked@15.0.7"
pin "turndown", to: "https://esm.sh/turndown@7.2.0"
pin "rete", to: "https://cdn.jsdelivr.net/npm/rete@2.0.5/+esm"
pin_all_from "app/javascript/controllers", under: "controllers"
