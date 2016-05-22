import PackageDescription

let package = Package(
    name: "PBRenderer",
    dependencies: [
                      .Package(url: "https://github.com/troughton/OpenGL.git", majorVersion: 2),
                      .Package(url: "https://github.com/troughton/Math.git", majorVersion: 1),
                      .Package(url: "https://github.com/troughton/CLibXML2.git", majorVersion: 1),
                      .Package(url: "https://github.com/troughton/CPBRendererLibs", majorVersion: 1)
                      ],
    targets: [
                 Target(name: "PBRendererApp", dependencies: [ .Target(name: "PBRenderer"), .Target(name: "ColladaParser")
                    ]),
                 Target(name: "PBRendererMusicApp", dependencies: [ .Target(name: "PBRenderer"), .Target(name: "ColladaParser")
                    ]),
                 Target(name: "PBRenderer", dependencies: [ .Target(name: "ColladaParser")
                                                               ]),
                 Target(name: "ColladaParser")
    ]
)

#if os(Linux)
package.dependencies.append(
    Package.Dependency.Package(url: "https://github.com/troughton/CGLFW3Linux.git", majorVersion: 1)
    // If your distro renamed the library to "glfw" (no 3) use this instead:
    // Package.Dependency.Package(url: "https://github.com/SwiftGL/CGLFWLinux.git", majorVersion: 1)
)
package.dependencies.append(Package.Dependency.Package(url: "https://github.com/troughton/OpenCL-Linux", majorVersion: 1))
#else
package.dependencies.append(
    Package.Dependency.Package(url: "https://github.com/SwiftGL/CGLFW3.git", majorVersion: 1)
)
#endif