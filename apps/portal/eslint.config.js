// ESLint configuration — VSP Portal
//
// This replaces a .eslintrc.json that could not have linted anything. It was
// written for a React/Next.js app — `plugin:react/recommended`,
// `react-hooks`, `next/core-web-vitals`, JSX parsing — while this portal is
// Vue 3, and it named four plugins that are not in package.json. On top of
// that, ESLint 9 reads flat config only, so `npm run lint` did not fall back
// to it or complain about the wrong framework: it exited with "couldn't find
// an eslint.config.js" and the pipeline moved on.
//
// So the lint gate has been failing open since ESLint was upgraded, and before
// that it would have failed on missing plugins. Nothing in src has ever been
// linted.
//
// Rules kept from the old file are the ones that still say something about
// this codebase; the React-specific half is gone because there is no React.

import js from '@eslint/js';
import pluginVue from 'eslint-plugin-vue';
import vueTsEslintConfig from '@vue/eslint-config-typescript';

export default [
  {
    ignores: [
      'dist/**',
      'coverage/**',
      'node_modules/**',
      '*.config.js',
      '*.config.ts',
    ],
  },

  js.configs.recommended,
  ...pluginVue.configs['flat/recommended'],
  ...vueTsEslintConfig(),

  {
    rules: {
      // Kept from the previous config.
      // `import type` for values, but inline `import()` in a type position is
      // allowed: typing a lazily-imported module — `typeof import('maplibre-gl')`
      // in the SSR-safe loader — is what the annotation is for, and a top-level
      // import of that module is exactly what the loader exists to avoid.
      '@typescript-eslint/consistent-type-imports': [
        'error',
        { disallowTypeAnnotations: false },
      ],
      '@typescript-eslint/no-explicit-any': 'warn',
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      'no-console': ['warn', { allow: ['warn', 'error'] }],
      'no-param-reassign': 'error',

      // The portal's own conventions. Single-word component names are the
      // Vue default complaint and every page here is index.vue by routing
      // convention, so that rule would fire on the file layout rather than on
      // anything a reviewer could act on.
      'vue/multi-word-component-names': 'off',

      // Formatting belongs to Prettier, which this project already has and
      // already runs. Leaving these on produced 1,534 warnings about where a
      // line break should go — noise that buries the two dozen findings that
      // are actually about the code, and that no reviewer would ever read
      // twice.
      'vue/max-attributes-per-line': 'off',
      'vue/singleline-html-element-content-newline': 'off',
      'vue/multiline-html-element-content-newline': 'off',
      'vue/html-indent': 'off',
      'vue/html-closing-bracket-newline': 'off',
      'vue/html-self-closing': 'off',
      'vue/attributes-order': 'off',
      'vue/first-attribute-linebreak': 'off',
    },
  },

  {
    // Tests reach for globals the browser build does not have.
    files: ['**/*.test.ts', '**/*.spec.ts'],
    rules: {
      'no-console': 'off',
      // Tests stub API shapes deliberately.
      '@typescript-eslint/no-explicit-any': 'off',
    },
  },
];
