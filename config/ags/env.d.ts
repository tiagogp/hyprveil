// Ambient module declarations for the AGS (Astal) build.
// AGS supplies the @girs typings; these cover the asset imports we use.
declare const SRC: string

declare module "*.scss" {
    const content: string
    export default content
}
declare module "*.css" {
    const content: string
    export default content
}
declare module "inline:*" {
    const content: string
    export default content
}
