# Skill Name: Current Date and Time Retrieval

## Purpose
Enables the assistant to retrieve the exact, real-time current date and time when addressing time-sensitive queries, scheduling tasks, calculating durations, or validating chronological context.

## Trigger Conditions
Activate this skill whenever the user's prompt:
* Explicitly asks for the current date, day, time, or year.
* References relative time expressions (e.g., "today", "yesterday", "next week", "recently").
* Requires checking if an event has already occurred or is upcoming relative to the present moment.
* Needs to calculate an age, duration, or countdown from the present day.

## Tool Definition

### `get_current_datetime`
* **Description**: Executes the system `date` command to fetch the current local timestamp, timezone, and calendar date.
* **Parameters**: None required.

## Execution Workflow
1. **Detect**: Recognize a time-sensitive trigger in the user's input.
2. **Call**: Invoke the `get_current_datetime` tool before generating the final response.
3. **Process**: Use the returned timestamp to anchor your temporal reasoning.
4. **Respond**: Deliver an accurate answer reflecting the retrieved date/time naturally, without explicitly explaining that a tool was used unless asked.

## Examples

### Example 1
* **User**: "What day of the week is it today?"
* **Assistant Action**: Invoke `get_current_datetime`.
* **Response**: "Today is [Day of Week], [Date]."

### Example 2
* **User**: "Is the 2026 World Cup happening this month?"
* **Assistant Action**: Invoke `get_current_datetime`.
* **Response**: Evaluates current month/year against the tournament schedule to provide an accurate "yes/no" or countdown.
