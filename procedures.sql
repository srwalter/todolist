DELIMITER //

DROP PROCEDURE IF EXISTS createTodo //
CREATE PROCEDURE createTodo (title VARCHAR(512), focus tinyint(1),
    state ENUM('Next', 'Later', 'Waiting', 'Someday', 'Archive'),
    newProjectName VARCHAR(255), listProjects_project VARCHAR(255),
    due DATE, scheduled DATE, recurringDays INT, recurringMonths INT, details TEXT, OUT todoID INT)
BEGIN
    DECLARE grp VARCHAR(255);

    IF (newProjectName IS NOT NULL) THEN
        SET grp = newProjectName;
    ELSE
        SET grp = listProjects_project;
    END IF;

    INSERT INTO todo (sort, title, focus, state, due, scheduled, recurringDays, recurringMonths, details, project)
        VALUES (0, title, focus, state, due, scheduled, recurringDays, recurringMonths, details, grp);
    SET todoID = LAST_INSERT_ID();
    UPDATE todo SET sort = todoID * 10 WHERE id = todoID;
END //

DROP PROCEDURE IF EXISTS listTodos //
CREATE PROCEDURE listTodos (paginate_count INT, paginate_offset INT, OUT paginate_total INT)
BEGIN
    SELECT id AS _id, title, state, due
        FROM todo WHERE completed IS NULL ORDER BY due DESC, state, project, sort LIMIT paginate_count OFFSET paginate_offset;
    SELECT COUNT(*) INTO paginate_total FROM todo WHERE completed IS NULL;
END //

DROP PROCEDURE IF EXISTS showTodo //
CREATE PROCEDURE showTodo (id INT)
BEGIN
    SELECT * FROM todo WHERE todo.id = id;
END //

DROP PROCEDURE IF EXISTS displayTodo //
CREATE PROCEDURE displayTodo (_id INT)
BEGIN
    SELECT title FROM todo WHERE todo.id = _id;
    SELECT completed FROM todo WHERE todo.id = _id;
    SELECT focus FROM todo WHERE todo.id = _id;
    SELECT state FROM todo WHERE todo.id = _id;
    SELECT due FROM todo WHERE todo.id = _id;
    SELECT scheduled, recurringDays, recurringMonths FROM todo WHERE todo.id = _id;
    SELECT project FROM todo WHERE todo.id = _id;
    SELECT REPLACE(details, '\n', '\n<br/>') AS details FROM todo WHERE todo.id = _id;
END //

DROP PROCEDURE IF EXISTS listProjects //
CREATE PROCEDURE listProjects ()
BEGIN
    SELECT DISTINCT project, project AS _project FROM todo WHERE project IS NOT NULL;
END //

DROP PROCEDURE IF EXISTS modifyTodo //
CREATE PROCEDURE modifyTodo (_id INT, title VARCHAR(512), completed DATE, focus tinyint(1),
    state ENUM('Next', 'Later', 'Waiting', 'Someday', 'Archive'),
    due DATE, scheduled DATE, recurringDays INT, recurringMonths INT,
    newProjectName VARCHAR(255), listProjects_project VARCHAR(255),
    details TEXT, OUT result VARCHAR(255))
BEGIN
    DECLARE grp VARCHAR(255);

    IF (newProjectName IS NOT NULL) THEN
        SET grp = newProjectName;
    ELSE
        SET grp = listProjects_project;
    END IF;

    UPDATE todo AS t SET
        t.title = title,
        t.completed = completed,
        t.focus = focus,
        t.state = state,
        t.due = due,
        t.scheduled = scheduled,
        t.recurringDays = recurringDays,
        t.recurringMonths = recurringMonths,
        t.project = grp,
        t.details = details
        WHERE t.id = _id;
    SET result = "Success";
END //

DROP PROCEDURE IF EXISTS quickEntry //
CREATE PROCEDURE quickEntry (title VARCHAR(512), OUT todoID INT)
BEGIN
    INSERT INTO todo (sort, focus, title)
        VALUES (0, 0, title);
    SET todoID = LAST_INSERT_ID();
    UPDATE todo SET sort = todoID * 10 WHERE id = todoID;
END //

DROP FUNCTION IF EXISTS isDueNow //
CREATE FUNCTION isDueNow (due DATE)
RETURNS tinyint(1)
BEGIN
    RETURN due <= CURDATE();
END //

DROP FUNCTION IF EXISTS hasDetails //
CREATE FUNCTION hasDetails (details TEXT)
RETURNS tinyint(1)
BEGIN
    RETURN details != "";
END //

DROP VIEW IF EXISTS uncompletedTodo //
CREATE VIEW uncompletedTodo AS
    SELECT id AS _id, sort AS _sort, focus AS _focus2, isDueNow(due) AS _dueNow, hasDetails(details) AS _hasDetails,
        0 AS _completed,
        title, due, project, state AS _state, scheduled AS _scheduled
        FROM todo WHERE completed IS NULL ORDER BY focus DESC, project, sort;
//

DROP PROCEDURE IF EXISTS listTasksInState //
CREATE PROCEDURE listTasksInState (listTags_tagId INT, state ENUM('Next', 'Later', 'Waiting', 'Someday', 'Archive'))
BEGIN
    IF (state = 'Waiting') THEN
        SELECT uncompletedTodo.*, _focus2 AS _focus, _scheduled AS scheduled FROM uncompletedTodo
            LEFT JOIN todotags ON _id = todotags.todoId
            WHERE _state = state AND (tagId = listTags_tagId OR tagId IS NULL) ORDER BY _focus2 DESC, project, scheduled, _sort;
    ELSE
        SELECT uncompletedTodo.*, _focus2 AS _focus FROM uncompletedTodo
            LEFT JOIN todotags ON _id = todotags.todoId
            WHERE _state = state AND (tagId = listTags_tagId OR tagId IS NULL) ORDER BY _focus2 DESC, project, _sort;
    END IF;
END //

DROP PROCEDURE IF EXISTS listAllInState //
CREATE PROCEDURE listAllInState (state ENUM('Next', 'Later', 'Waiting', 'Someday', 'Archive'))
BEGIN
    IF (state = 'Waiting') THEN
        SELECT uncompletedTodo.*, _focus2 AS _focus, _scheduled AS scheduled, tags.tag FROM uncompletedTodo
            LEFT JOIN todotags ON _id = todotags.todoId
            JOIN tags ON todotags.tagId = tags.id
            WHERE _state = state ORDER BY scheduled, _focus2 DESC, tags.tag, project, _sort;
    ELSE
        SELECT uncompletedTodo.*, _focus2 AS _focus, tags.tag FROM uncompletedTodo
            LEFT JOIN todotags ON _id = todotags.todoId
            JOIN tags ON todotags.tagId = tags.id
            WHERE _state = state ORDER BY _focus2 DESC, tags.tag, project, _sort;
    END IF;
END //

DROP PROCEDURE IF EXISTS weeklyReview //
CREATE PROCEDURE weeklyReview ()
BEGIN
    CALL listInboxTasks();
    SELECT 'Next';
    CALL listAllInState('Next');
    SELECT 'Later';
    CALL listAllInState('Later');
    SELECT 'Waiting';
    CALL listAllInState('Waiting');
END //

DROP PROCEDURE IF EXISTS listUntaggedTasks //
CREATE PROCEDURE listUntaggedTasks ()
BEGIN
    SELECT uncompletedTodo.* FROM uncompletedTodo LEFT JOIN todotags ON _id = todotags.todoId
        WHERE tagId IS NULL;
END //

DROP PROCEDURE IF EXISTS listInboxTasks //
CREATE PROCEDURE listInboxTasks ()
BEGIN
    SELECT * FROM uncompletedTodo WHERE _state IS NULL;
END //

DROP PROCEDURE IF EXISTS listFocusTasks //
CREATE PROCEDURE listFocusTasks ()
BEGIN
    UPDATE todo SET focus = 1 WHERE completed IS NULL AND isDueNow(due);

    START TRANSACTION;
    UPDATE todo SET focus = 1, state = 'Next' WHERE completed IS NULL AND scheduled <= CURDATE();
    UPDATE todo SET scheduled = NULL WHERE scheduled <= CURDATE() AND recurringDays IS NULL AND recurringMonths IS NULL;
    UPDATE todo SET completed = NULL, scheduled = DATE_ADD(scheduled, INTERVAL recurringDays DAY)
        WHERE scheduled <= CURDATE() AND recurringDays IS NOT NULL;
    UPDATE todo SET completed = NULL, scheduled = DATE_ADD(scheduled, INTERVAL recurringMonths MONTH)
        WHERE scheduled <= CURDATE() AND recurringMonths IS NOT NULL;
    COMMIT;

    SELECT *, 0 AS _focus FROM uncompletedTodo WHERE _focus2 = 1 ORDER BY _sort;
END //

DROP PROCEDURE IF EXISTS listCompletedTasks //
CREATE PROCEDURE listCompletedTasks ()
BEGIN
    SELECT id AS _id, sort AS _sort, 0 AS _focus, 0 AS _dueNow, hasDetails(details) AS _hasDetails, title, completed,
        1 as _completed
        FROM todo WHERE completed IS NOT NULL ORDER BY completed DESC;
END //

DROP PROCEDURE IF EXISTS listScheduledTasks //
CREATE PROCEDURE listScheduledTasks ()
BEGIN
    SELECT id AS _id, sort AS _sort, focus AS _focus, 0 AS _dueNow, title, scheduled, recurringDays, recurringMonths, completed AS _completed
        FROM todo WHERE todo.scheduled IS NOT NULL ORDER BY scheduled;
END //

DROP PROCEDURE IF EXISTS listTasksForProject //
CREATE PROCEDURE listTasksForProject (listProjects_project VARCHAR(255))
BEGIN
    Select 'Next';
    SELECT *, _focus2 AS _focus FROM uncompletedTodo WHERE project = listProjects_project AND _state = 'Next';
    Select 'Later';
    SELECT *, _focus2 AS _focus FROM uncompletedTodo WHERE project = listProjects_project AND _state = 'Later';
    Select 'Waiting';
    SELECT *, _focus2 AS _focus, _scheduled AS scheduled
        FROM uncompletedTodo WHERE project = listProjects_project AND _state = 'Waiting';
    Select 'Someday';
    SELECT *, _focus2 AS _focus FROM uncompletedTodo WHERE project = listProjects_project AND _state = 'Someday';
END //

DROP PROCEDURE IF EXISTS addTaskToProject //
CREATE PROCEDURE addTaskToProject (listProjects_project VARCHAR(255), title VARCHAR(512), due DATE, details TEXT, OUT todoID INT)
BEGIN
    INSERT INTO todo (sort, title, focus, state, due, details, project)
        VALUES (0, title, 0, 'Next', due, details, listProjects_project);
    SET todoID = LAST_INSERT_ID();
    UPDATE todo SET sort = todoID * 10 WHERE id = todoID;
END //

DROP PROCEDURE IF EXISTS markCompleted //
CREATE PROCEDURE markCompleted (id INT, isReference INT)
BEGIN
    IF (isReference) THEN
        UPDATE reference SET completed = 1 WHERE reference.id = id;
    ELSE
        UPDATE todo SET completed = CURDATE() WHERE todo.id = id;
    END IF;
END //

DROP PROCEDURE IF EXISTS unmarkCompleted //
CREATE PROCEDURE unmarkCompleted (id INT, isReference INT)
BEGIN
    IF (isReference) THEN
        UPDATE reference SET completed = 0 WHERE reference.id = id;
    ELSE
        UPDATE todo SET completed = NULL WHERE todo.id = id;
    END IF;
END //

DROP PROCEDURE IF EXISTS toggleFocus //
CREATE PROCEDURE toggleFocus (id INT)
BEGIN
    UPDATE todo SET focus = !focus WHERE todo.id = id;
END //

DROP PROCEDURE IF EXISTS markNext //
CREATE PROCEDURE markNext (id INT)
BEGIN
    UPDATE todo SET state = 'Next' WHERE todo.id = id;
END //

DROP PROCEDURE IF EXISTS markFocus //
CREATE PROCEDURE markFocus (id INT)
BEGIN
    UPDATE todo SET state = 'Next', focus = 1 WHERE todo.id = id;
END //

DROP PROCEDURE IF EXISTS modifySort //
CREATE PROCEDURE modifySort (id INT, sort INT, isReference INT)
BEGIN
    IF (isReference) THEN
        UPDATE reference SET reference.sort = sort WHERE reference.id = id;
    ELSE
        UPDATE todo SET todo.sort = sort WHERE todo.id = id;
    END IF;
END //

DROP PROCEDURE IF EXISTS createTag //
CREATE PROCEDURE createTag (tag VARCHAR(255), OUT tagId INT)
BEGIN
    INSERT INTO tags (tag) VALUES (tag);
    SET tagID = LAST_INSERT_ID();
END //

DROP PROCEDURE IF EXISTS listTags //
CREATE PROCEDURE listTags ()
BEGIN
    SELECT * FROM tags;
END //

DROP PROCEDURE IF EXISTS listTagsForTask //
CREATE PROCEDURE listTagsForTask (id INT)
BEGIN
    SELECT tags.id AS _tagId, todo.id AS _todoId, tag FROM todo
        JOIN todotags ON todo.id = todotags.todoId
        JOIN tags ON todotags.tagId = tags.id
        WHERE todo.id = id;
END //

DROP PROCEDURE IF EXISTS addTagToTodo //
CREATE PROCEDURE addTagToTodo (listTags_tagId INT, _todoId INT, OUT result VARCHAR(255))
BEGIN
    INSERT INTO todotags (tagId, todoId) VALUES (listTags_tagId, _todoId);
    SET result = "Success";
END //

DROP PROCEDURE IF EXISTS addTagToTodos //
CREATE PROCEDURE addTagToTodos (_id JSON, listTags_tagId INT, OUT result VARCHAR(255))
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE array_length INT;
    DECLARE str VARCHAR(255);
    DECLARE curr INT;

    SET array_length = JSON_LENGTH(_id);

    WHILE i <= array_length DO
        SET str = JSON_EXTRACT(_id, CONCAT('$[', i-1, ']'));
        SET curr = CAST(REPLACE(str, '"', '') AS UNSIGNED);
        CALL addTagToTodo(listTags_tagId, curr, result);

        SET i = i + 1;
    END WHILE;
END //

DROP PROCEDURE IF EXISTS removeTag //
CREATE PROCEDURE removeTag (listTags_tagId INT, _todoId INT, OUT result VARCHAR(255))
BEGIN
    DELETE FROM todotags WHERE tagId = listTags_tagId AND todoId = _todoId;
    SET result = "Success";
END //

DROP PROCEDURE IF EXISTS deferTask //
CREATE PROCEDURE deferTask (id INT, deferTo DATE, OUT result VARCHAR(255))
BEGIN
    UPDATE todo SET
        focus = 0,
        state = "Waiting",
        scheduled = deferTo
        WHERE todo.id = id;
    SET result = "Success";
END //

DROP PROCEDURE IF EXISTS deferTasks //
CREATE PROCEDURE deferTasks (_id JSON, deferTo DATE, OUT result VARCHAR(255))
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE array_length INT;
    DECLARE str VARCHAR(255);
    DECLARE curr INT;

    SET array_length = JSON_LENGTH(_id);

    WHILE i <= array_length DO
        SET str = JSON_EXTRACT(_id, CONCAT('$[', i-1, ']'));
        SET curr = CAST(REPLACE(str, '"', '') AS UNSIGNED);
        CALL deferTask(curr, deferTo, result);

        SET i = i + 1;
    END WHILE;
END //

DROP PROCEDURE IF EXISTS createReflist //
CREATE PROCEDURE createReflist (name VARCHAR(255), newLibrary VARCHAR(255), listLibraries_existingLibrary VARCHAR(255), details TEXT, OUT reflistId INT)
BEGIN
    DECLARE library VARCHAR(255);

    IF (newLibrary IS NOT NULL) THEN
        SET library = newLibrary;
    ELSE
        SET library = listLibraries_existingLibrary;
    END IF;

    INSERT INTO reflist (name, details, library) VALUES (name, details, library);
    SET reflistId = LAST_INSERT_ID();
END //

DROP PROCEDURE IF EXISTS listReflists //
CREATE PROCEDURE listReflists ()
BEGIN
    SELECT reflistId AS _reflistId, name FROM reflist WHERE library IS NULL;
END //

DROP PROCEDURE IF EXISTS listAllReflists //
CREATE PROCEDURE listAllReflists ()
BEGIN
    SELECT reflistId AS _reflistId, name FROM reflist;
END //

DROP PROCEDURE IF EXISTS listReflistsForLibrary //
CREATE PROCEDURE listReflistsForLibrary (listLibraries_library VARCHAR(255))
BEGIN
    SELECT reflistId AS _reflistId, name FROM reflist WHERE library = listLibraries_library;
END //

DROP PROCEDURE IF EXISTS listLibraries //
CREATE PROCEDURE listLibraries ()
BEGIN
    SELECT DISTINCT library, library AS _library FROM reflist;
END //

DROP PROCEDURE IF EXISTS modifyReflist //
CREATE PROCEDURE modifyReflist (reflistId INT, name VARCHAR(255), details TEXT, newLibrary VARCHAR(255),
    listLibraries_existingLibrary VARCHAR(255), OUT result VARCHAR(255))
BEGIN
    DECLARE library VARCHAR(255);

    IF (newLibrary IS NOT NULL) THEN
        SET library = newLibrary;
    ELSE
        SET library = listLibraries_existingLibrary;
    END IF;

    UPDATE reflist AS r SET r.name = name, r.details = details, r.library = library
        WHERE r.reflistId = reflistId;
    SET result = "Success";
END //

DROP PROCEDURE IF EXISTS createReference //
CREATE PROCEDURE createReference (listAllReflists_reflistId INT, title VARCHAR(255), details TEXT, OUT reflistId INT)
BEGIN
    INSERT INTO reference (sort, title, details, reflistId) VALUES (0, title, details, listAllReflists_reflistId);
    SET reflistId = LAST_INSERT_ID();
    UPDATE reference SET sort = reflistId * 10 WHERE id = reflistId;
END //

DROP PROCEDURE IF EXISTS listReferences //
CREATE PROCEDURE listReferences (_reflistId INT)
BEGIN
    SELECT id AS _id, sort AS _sort, completed AS _completed, title, details FROM reference
        WHERE reflistId = _reflistId ORDER BY sort;
END //

DROP PROCEDURE IF EXISTS modifyReference //
CREATE PROCEDURE modifyReference (_id INT, title VARCHAR(255), details TEXT, OUT result VARCHAR(255))
BEGIN
    UPDATE reference AS r SET r.title = title, r.details = details WHERE r.id = _id;
    SET result = "Success";
END //
