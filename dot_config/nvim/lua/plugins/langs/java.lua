return {
  {
    "nvim-java/nvim-java",
    config = false,
    dependencies = {
      {
        "neovim/nvim-lspconfig",
        opts = {
          servers = {
            jdtls = {
              -- Your custom jdtls settings goes here
            },
          },
          setup = {
            jdtls = function()
              require("java").setup({
                spring_boot_tools = {
                  enable = true,
                },
                java_test = {
                  enable = true,
                },
                jdk = {
                  auto_install = false,
                },
                verification = {
                  duplicate_setup_calls = false,
                },
                root_markers = {
                  "settings.gradle",
                  "settings.gradle.kts",
                  "pom.xml",
                  "build.gradle",
                  "mvnw",
                  "gradlew",
                  "build.gradle",
                  "build.gradle.kts",
                },
                completion = {
                  favorite_static_members = {
                    "org.hamcrest.MatcherAssert.assertThat",
                    "org.hamcrest.Matchers.*",
                    "org.hamcrest.CoreMatchers.*",
                    "org.junit.jupiter.api.Assertions.*",
                    "java.util.Objects.requireNonNull",
                    "java.util.Objects.requireNonNullElse",
                    "org.mockito.Mockito.*",
                  },
                  sources = {
                    organize_imports = {
                      star_threshold = 9999,
                      static_start_threshold = 9999,
                    },
                  },
                  code_generation = {
                    toString = {
                      template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
                    },
                    hashCodeEquals = {
                      useJava7Objects = true,
                    },
                    useBlocks = true,
                  },
                },
              })
            end,
          },
        },
      },
    },
  },
}
