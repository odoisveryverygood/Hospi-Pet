import js from '@eslint/js';
import tseslint from 'typescript-eslint';
export default tseslint.config(
  { ignores: ['legacy/**', 'dist/**', 'coverage/**', 'test-results/**', 'playwright-report/**', '.jac/**'] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
);
