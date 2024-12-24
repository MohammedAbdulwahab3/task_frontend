import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TaskListScreen(),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List tasks = [];

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  Future<void> fetchTasks() async {
    final response =
        await http.get(Uri.parse('http://127.0.0.1:8000/api/tasks/'));
    if (response.statusCode == 200) {
      setState(() {
        tasks = json.decode(response.body);
      });
    } else {
      throw Exception('Failed to load tasks');
    }
  }

  Future<void> deleteTask(int taskId) async {
    // Remove from UI instantly
    setState(() {
      tasks.removeWhere((task) => task['id'] == taskId);
    });

    // Make API call to delete the task
    final response = await http.delete(
      Uri.parse('http://127.0.0.1:8000/api/tasks/$taskId/delete/'),
    );
    if (response.statusCode != 204) {
      // If deletion fails, restore the task
      fetchTasks();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete task')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task deleted successfully')),
      );
    }
  }

  Future<void> editTask(int taskId, String updatedName) async {
    // Update UI instantly with new task name
    final updatedTask = {
      ...tasks.firstWhere((task) => task['id'] == taskId),
      'name': updatedName
    };
    setState(() {
      tasks[tasks.indexWhere((task) => task['id'] == taskId)] = updatedTask;
    });

    // Make API call to update the task
    final response = await http.put(
      Uri.parse('http://127.0.0.1:8000/api/tasks/$taskId/'),
      body: json.encode({'name': updatedName}),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      // If update fails, revert the name change
      setState(() {
        tasks[tasks.indexWhere((task) => task['id'] == taskId)] = {
          'id': taskId,
          'name': tasks.firstWhere((task) => task['id'] == taskId)['name']
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update task')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task updated successfully')),
      );
    }
  }

  Future<void> addTask(String name) async {
    // Create a temporary task object and add it to the list immediately
    final newTask = {
      'id': null, // Temporarily set to null until the backend assigns an ID
      'name': name,
    };

    // Update the UI immediately
    setState(() {
      tasks.add(newTask);
    });

    // Make API call to add the task
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8000/api/tasks/add/'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"name": name}),
    );

    if (response.statusCode == 201) {
      // If the API call is successful, update the task with the actual ID
      final taskWithId = json.decode(response.body);
      setState(() {
        // Find the temporary task and replace it with the task from the server
        tasks[tasks.indexWhere((task) => task['name'] == name)] = taskWithId;
      });
    } else {
      // If the addition fails, remove the task from the UI and show an error
      setState(() {
        tasks.removeWhere((task) => task['name'] == name);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add task')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tasks',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 4,
      ),
      body: tasks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 6,
                  shadowColor: Colors.black.withOpacity(0.1),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                    leading: const Icon(
                      Icons.task_alt,
                      color: Colors.blueAccent,
                    ),
                    title: Text(
                      tasks[index]['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.red),
                          onPressed: () async {
                            final editedName = await showDialog<String>(
                              context: context,
                              builder: (context) {
                                final controller = TextEditingController(
                                  text: tasks[index]['name'],
                                );
                                return AlertDialog(
                                  title: const Text('Edit Task'),
                                  content: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                        hintText: 'Enter new task name'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context, controller.text);
                                      },
                                      child: const Text('Save'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (editedName != null && editedName.isNotEmpty) {
                              await editTask(tasks[index]['id'], editedName);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
                          onPressed: () => deleteTask(tasks[index]['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newTaskName = await showDialog<String>(
            context: context,
            builder: (context) {
              final controller = TextEditingController();
              return AlertDialog(
                title: const Text('Add New Task'),
                content: TextField(
                  controller: controller,
                  decoration:
                      const InputDecoration(hintText: 'Enter task name'),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, controller.text);
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          );
          if (newTaskName != null && newTaskName.isNotEmpty) {
            await addTask(newTaskName);
          }
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
    );
  }
}
