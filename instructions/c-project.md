# C Projects Agent Instructions

## Coding Style & Naming Conventions

### Formatting

C/C++ formatting follows the following rules:

- 4-space indentation, NO tabs.
- NO column limit.
- When a function declaration or call is too long, place each argument on a separate line and align the arguments after the opening parenthesis:

  ```c
  ErrCode parse_setting_result_from_response(char* response,
                                              ResultCode* code,
                                              char* description,
                                              ToolCall tool_call[],
                                              int tool_call_num)
  ```

- Keep at most one consecutive empty line.
- Left-align pointer declarators.
- Use one space before trailing comments.

Do NOT run `clang-format` to format any changed C/C++ files.

### Naming

- Use lower_snake_case for C files, headers, functions, and local variables.
- Public functions should use names such as `calculate_len()`.
- Static private functions should use a leading underscore, such as `_calculate_len()`.
- Use all-uppercase names for macros, such as `DEFAULT_WORKER_PRIORITY`.
- Format enum types and enumerators as follows:

  ```c
  typedef enum StatusCode {
      kStatusCodeOk = 0,
      kStatusCodeFail,
      kStatusCodeRuning,
      kStatusCodeStop,
      kStatusCodeInvalid,
  } StatusCode;
  ```

- Format structures as follows:

  ```c
  typedef struct ActiveObject {
      void* _context;
      State _state;
      MessageQueue* _msg // private variable

      int
  } ActiveObject;
  ```

### Comment

- Add function comments with `@brief`, `@param`, and `@return` for new or changed functions.
- Public declarations in headers need matching comments.
- Document structs with a struct-level description and field descriptions.
- Add process comments and comments explaining `if` branches inside functions.

## Commit Message Guidelines

- Use Conventional Commit subjects in the form `type(scope): summary`, such as `feat(alarm): support deep sleep RTC wake` and `fix(config): increase TCP window size to 11200`.
- Common types are `feat`, `fix`, `refactor`, `test`, `docs`, and `chore`.
- Keep the type and scope lowercase, and write a concise English summary that starts with an imperative verb.
