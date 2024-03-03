import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 1, 97, 89)),
      ),
      home: const MyHomePage(title: 'Daily Check'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // todo: creat a map for saving the entries
  List<Task> tasksForYesterday = [];
  List<Task> tasksForToday = [];
  List<Task> tasksForTomorrow = [];
  final Color mainColor = const Color.fromARGB(255, 1, 97, 89);
  final Color white = Colors.white;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    loadTasks(); // Load tasks when the app starts
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mainColor,
      appBar: buildTabBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Container of Yesterday
          Container(
            color: white,
            child: ListView(
              children: buildTaskList(tasksForYesterday),
            ),
          ),
          // Container of today
          buildDayContainer(TaskRemark.today),
          // Container of tomorrow
          buildDayContainer(TaskRemark.tomorrow),
        ],
      ),
    );
  }

  @override
  void dispose() {
    saveTasks(); // Save tasks when the app is disposed
    _tabController.dispose();
    super.dispose();
  }

  // Dialog to add new tasks, the task remark tell us in which tab the task has to be added
  void showAddTaskDialog(BuildContext context, TaskRemark taskRemark) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newTask = ''; // Variable to store the input from TextField

        return AlertDialog(
          title: const Text('Add Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                onChanged: (value) {
                  newTask = value; // Update newTask when the TextField changes
                },
                decoration: const InputDecoration(
                  hintText: 'Enter task name',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (newTask.isNotEmpty) {
                  setState(() {
                    createNewTask(taskRemark, newTask);
                  });
                }
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Method to build task list, the parameter is task list that will be builded
  List<Widget> buildTaskList(List taskList) {
    return taskList.asMap().entries.map((entry) {
      final index = entry.key;
      final task = entry.value;
      return Dismissible(
        // Use UniqueKey for each Dismissible, the index of the task will cause problems beacuse of the reordering method
        key: UniqueKey(),
        direction: DismissDirection.endToStart, // Swipe direction
        onDismissed: (direction) {
          // Remove task from the list
          setState(() {
            taskList.removeAt(index);
          });
        },
        background: Container(
          color: Colors.red, // Background color when swiping
        ),
        child: ListTile(
          leading: Text('${index + 1}'), // Display task index on the left
          title: Text(task.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: task.isDone,
                onChanged: (value) {
                  setState(() {
                    task.isDone = value ?? false; // Update task state
                  });
                },
                activeColor: Colors.green, // Set color of tick when checked
              ),
              IconButton(
                icon: const Icon(Icons.move_up),
                onPressed: () {
                  setState(() {
                    moveTaskToAnotherDay(taskList, task, index);
                  });
                },
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  DateTime calculateDateForTask(TaskRemark remark) {
    switch (remark) {
      case TaskRemark.yesterday:
        return DateTime.now().subtract(const Duration(days: 1));
      case TaskRemark.today:
        return DateTime.now();
      case TaskRemark.tomorrow:
        return DateTime.now().add(const Duration(days: 1));
      case TaskRemark.none: // This case should not be achieved
        return DateTime.now();
    }
  }

  // Callback function for reordering tasks
  void onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1; // Adjust newIndex if item is moved down in the list
      }
      if (_tabController.index == 0) {
        final task = tasksForYesterday.removeAt(oldIndex);
        tasksForYesterday.insert(newIndex, task);
      } else if (_tabController.index == 1) {
        final task = tasksForToday.removeAt(oldIndex);
        tasksForToday.insert(newIndex, task);
      } else if (_tabController.index == 2) {
        final task = tasksForTomorrow.removeAt(oldIndex);
        tasksForTomorrow.insert(newIndex, task);
      }
    });
  }

  // Load all tasks from the device
  void loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      List<Task> tempTasksForYesterday = loadTaskList(prefs, 'yesterday');
      List<Task> tempTasksForToday = loadTaskList(prefs, 'today');
      List<Task> tempTasksForTomorrow = loadTaskList(prefs, 'tomorrow');

      taskDistributation(tempTasksForYesterday);
      taskDistributation(tempTasksForToday);
      taskDistributation(tempTasksForTomorrow);
      clearAllValues(); // clear device memorry after loading is complete
    });
  }

  // Put the task in one of the task lists based on it's date (a date is valid when date + 1 = today or date -1 or eq to to today)
  void taskDistributation(List<Task> savedTaskList) {
    DateTime today = DateTime.now();
    for (Task task in savedTaskList) {
      if (task.localDate == today) {
        tasksForToday.add(task);
      } else if (task.localDate == today.add(const Duration(days: 1))) {
        tasksForTomorrow.add(task);
      } else if (task.localDate == today.subtract(const Duration(days: 1))) {
        tasksForYesterday.add(task);
      }
    }
  }

  void clearAllValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.clear(); // Remove all values
    await prefs.reload(); // Apply changes asynchronously
  }

  // Load the task list for specific date from the device memmory, where key is the sign of the date
  List<Task> loadTaskList(SharedPreferences prefs, String key) {
    final taskList = prefs.getStringList(key);
    if (taskList == null) {
      return [];
    }
    return taskList.map((taskString) {
      final taskParts = taskString.split(',');
      return Task(
        name: taskParts[0],
        isDone: taskParts[1] == 'true',
        remark: TaskRemark.values[int.parse(taskParts[2])],
        localDate: DateTime.parse(taskParts[3]),
      );
    }).toList();
  }

  void saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    saveTaskList(prefs, 'yesterday', tasksForYesterday);
    saveTaskList(prefs, 'today', tasksForToday);
    saveTaskList(prefs, 'tomorrow', tasksForTomorrow);
  }

  void saveTaskList(SharedPreferences prefs, String key, List<Task> tasks) {
    final taskList = tasks.map((task) {
      return '${task.name},${task.isDone},${task.remark.index},${task.localDate}';
    }).toList();
    prefs.setStringList(key, taskList);
  }

  void moveTaskToAnotherDay(List taskList, task, int index) {
    // Remove task from the current list
    taskList.removeAt(index);
    // Update task remark and date
    task.localDate = calculateDateForTask(task.remark);
    // Add task to the new list
    if (task.remark == TaskRemark.today) {
      task.remark = TaskRemark.tomorrow;
      tasksForToday.remove(task);
      tasksForTomorrow.add(task);
    } else if (task.remark == TaskRemark.tomorrow ||
        task.remark == TaskRemark.yesterday) {
      task.remark = TaskRemark.today;
      tasksForTomorrow.remove(task);
      tasksForToday.add(task);
    }
  }

  void createNewTask(TaskRemark taskRemark, String newTask) {
    Task newTaskToBeDone = Task(
        name: newTask,
        isDone: false,
        remark: taskRemark,
        localDate: DateTime.now());
    if (taskRemark == TaskRemark.today) {
      tasksForToday.add(newTaskToBeDone);
    } else if (taskRemark == TaskRemark.tomorrow) {
      tasksForTomorrow.add(newTaskToBeDone);
    }
  }

  // build day container either for today or tomorrow based on the remark.
  Container buildDayContainer(TaskRemark remark) {
    return Container(
      color: white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: ReorderableListView(
              onReorder: onReorder,
              children: buildTaskList(remark == TaskRemark.today
                  ? tasksForToday
                  : tasksForTomorrow), // Build task list
            ),
          ),
          const SizedBox(height: 20), // Add space between list and button
          Padding(
            padding: const EdgeInsets.only(
                bottom: 20), // Add space between button and bottom
            child: FloatingActionButton(
              onPressed: () {
                showAddTaskDialog(context, remark);
              },
              backgroundColor: mainColor,// Button background color
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                  const Icon(
                    Icons.add,
                    color: Color.fromARGB(255, 1, 97, 89),
                    size: 40,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TabBar buildTabBar() {
    return TabBar(
      controller: _tabController,
      indicatorColor: white,
      labelColor: white,
      unselectedLabelColor: Colors.grey,
      tabs: const [
        Tab(text: 'Yestarday'),
        Tab(text: 'Today'),
        Tab(text: 'Tomorrow'),
      ],
    );
  }
}

// Task class to represent individual tasks
class Task {
  final String name;
  bool isDone;
  TaskRemark remark;
  DateTime localDate;

  Task({
    required this.name,
    required this.isDone,
    this.remark = TaskRemark.none,
    required this.localDate,
  });
}

enum TaskRemark {
  none,
  yesterday,
  today,
  tomorrow,
}
