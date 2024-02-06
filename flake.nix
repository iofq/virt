{
  description = "Virsh wrapper script for easy VM creation";

  # Nixpkgs / NixOS version to use.
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs}:
    let
      version = "0.1.0";
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });
    in
    {
      overlay = final: prev: {
        iofq-virt = with final; stdenv.mkDerivation {
          name = "iofq-virt-${version}";
          src = self;
          nativeBuildInputs = [ pkgs.makeWrapper ];
          dontBuild = true;
          installPhase = "
            install -Dm755 virt-install.sh $out/bin/iofq-virt
            patchShebangs $out/bin/iofq-virt
            wrapProgram $out/bin/iofq-virt --set PATH '${lib.makeBinPath [
                cdrkit
                coreutils
                libguestfs
                libvirt
                qemu-utils
                sudo
              ]}'
          ";
        };
      };

      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) iofq-virt;
        });
      defaultPackage = forAllSystems (system: self.packages.${system}.iofq-virt);
    };
}
