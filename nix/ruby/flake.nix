{
  # nixpkgs に Ruby 4.0.10 が取り込まれるまでの一時的な定義。
  # nixpkgs 本体は devbox.json で使っていたコミットに固定し、Ruby の版とハッシュだけを差し替える。
  # 取り込まれたら devbox.json を nixpkgs の ruby_4_0 指定へ戻し、このディレクトリを削除する。
  # 追跡用: https://github.com/NixOS/nixpkgs/pull/590173
  description = "Ruby 4.0.10 for touhou_karaoke_admin";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/5d2b81a7a3be3e2f832879028e4d60abbf58e9a0";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: {
        default = pkgs.mkRuby {
          version = pkgs.mkRubyVersion "4" "0" "10" "";
          # https://cache.ruby-lang.org/pub/ruby/4.0/ruby-4.0.10.tar.gz
          # sha256: b53eef3371fa5d3e3b74340edcd015f06d5d8853968d4e539a5264fce41ed9f1
          hash = "sha256-tT7vM3H6XT47dDQO3NAV8G1diFOWjU5TmlJk/OQe2fE=";
          cargoHash = "sha256-z7NwWc4TaR042hNx0xgRkh/BQEpEJtE53cfrN0qNiE0=";
        };
      });
    };
}
