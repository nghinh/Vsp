/**
 * VSP Portal UI — TypeScript Declarations
 *
 * Declare CSS module imports so TypeScript typechecking passes.
 */

declare module '*.css' {
  const content: Record<string, string>;
  export default content;
}
