// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';

class AppColors {
  static const Color primario = Color(0xFF4B5AE4);
  static const Color primarioClaro = Color(0xFF6B7FFF);
  static const Color fondoPrincipal = Color(0xFFF8F9FF);
  static const Color fondoInput = Color(0xFFF0F2FF);
  static const Color textoBlanco = Color(0xFFFFFFFF);
  static const Color textoOscuro = Color(0xFF1A1D2E);
  static const Color textoMedio = Color(0xFF6B7280);
  static const Color exito = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
}

class PerfilScreen extends StatefulWidget {
  final String correoUsuario;
  final String nombreUsuario;
  final String? fotoPerfil;
  final bool shouldReload;

  const PerfilScreen({
    super.key,
    required this.correoUsuario,
    required this.nombreUsuario,
    this.fotoPerfil,
    this.shouldReload = false,
  });

  @override
  _PerfilScreenState createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _nombreController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isLoadingProfile = true;
  String? _fotoPerfilBase64;
  String _nombreActual = '';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void didUpdateWidget(PerfilScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recargar cuando shouldReload cambia de false a true
    if (widget.shouldReload && !oldWidget.shouldReload) {
      _cargarPerfil();
    }
  }

  Future<void> _cargarPerfil() async {
    setState(() {
      _isLoadingProfile = true;
    });

    final url = Uri.parse(
      'http://192.168.56.1:8000/movil/perfil/${widget.correoUsuario}',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final datos = jsonDecode(response.body);
        setState(() {
          _nombreActual = datos['nombre_completo'] ?? widget.nombreUsuario;
          _nombreController.text = _nombreActual;
          _fotoPerfilBase64 = datos['foto_perfil'];
          _isLoadingProfile = false;
        });
      } else {
        setState(() {
          _nombreActual = widget.nombreUsuario;
          _nombreController.text = _nombreActual;
          _fotoPerfilBase64 = widget.fotoPerfil;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      setState(() {
        _nombreActual = widget.nombreUsuario;
        _nombreController.text = _nombreActual;
        _fotoPerfilBase64 = widget.fotoPerfil;
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _seleccionarFoto() async {
    final XFile? imagen = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 85,
    );

    if (imagen != null) {
      final bytes = await imagen.readAsBytes();
      setState(() {
        _fotoPerfilBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _guardarCambios() async {
    if (_nombreController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre no puede estar vacío'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_passwordController.text.isNotEmpty) {
      if (_passwordController.text != _confirmarPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Las contraseñas no coinciden'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_passwordController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La contraseña debe tener al menos 6 caracteres'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse(
      'http://192.168.56.1:8000/movil/perfil/${widget.correoUsuario}',
    );

    try {
      final body = <String, dynamic>{
        'nombre_completo': _nombreController.text.trim(),
      };

      if (_passwordController.text.isNotEmpty) {
        body['password'] = _passwordController.text;
      }

      if (_fotoPerfilBase64 != null) {
        body['foto_perfil'] = _fotoPerfilBase64;
      }

      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado exitosamente'),
            backgroundColor: AppColors.exito,
          ),
        );

        // Recargar el perfil desde la API
        await _cargarPerfil();

        setState(() {
          _isEditing = false;
          _passwordController.clear();
          _confirmarPasswordController.clear();
        });
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error['detail'] ?? 'Error al actualizar perfil'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return Column(
        children: [
          // Barra superior
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primario, AppColors.primarioClaro],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Mi Perfil',
                  style: TextStyle(
                    color: AppColors.textoBlanco,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primario),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Barra superior con gradiente
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primario, AppColors.primarioClaro],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mi Perfil',
                  style: TextStyle(
                    color: AppColors.textoBlanco,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isEditing ? Icons.close : Icons.edit,
                    color: AppColors.textoBlanco,
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      _isEditing = !_isEditing;
                      if (!_isEditing) {
                        _passwordController.clear();
                        _confirmarPasswordController.clear();
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        // Contenido del perfil
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Foto de perfil
                GestureDetector(
                  onTap: _isEditing ? _seleccionarFoto : null,
                  child: Stack(
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primario,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primario.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _fotoPerfilBase64 != null
                              ? Image.memory(
                                  base64Decode(_fotoPerfilBase64!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: AppColors.primario.withValues(
                                        alpha: 0.1,
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        size: 70,
                                        color: AppColors.primario,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: AppColors.primario.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    size: 70,
                                    color: AppColors.primario,
                                  ),
                                ),
                        ),
                      ),
                      if (_isEditing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primario,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.textoBlanco,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: AppColors.textoBlanco,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Correo (no editable)
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.email_outlined,
                        color: AppColors.textoMedio,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Correo electrónico',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textoMedio,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.correoUsuario,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textoOscuro,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Campo nombre
                TextField(
                  controller: _nombreController,
                  enabled: _isEditing,
                  decoration: InputDecoration(
                    labelText: 'Nombre completo',
                    labelStyle: TextStyle(color: AppColors.textoMedio),
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: AppColors.primario,
                    ),
                    filled: true,
                    fillColor: _isEditing
                        ? AppColors.fondoInput
                        : Colors.grey.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        color: AppColors.primario,
                        width: 2,
                      ),
                    ),
                  ),
                  style: const TextStyle(color: AppColors.textoOscuro),
                ),

                if (_isEditing) ...[
                  const SizedBox(height: 20),

                  // Campo nueva contraseña
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña (opcional)',
                      labelStyle: TextStyle(color: AppColors.textoMedio),
                      hintText: 'Dejar vacío para mantener actual',
                      hintStyle: TextStyle(
                        color: AppColors.textoMedio.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: AppColors.primario,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.textoMedio,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: AppColors.fondoInput,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: AppColors.primario,
                          width: 2,
                        ),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textoOscuro),
                  ),

                  const SizedBox(height: 15),

                  // Confirmar contraseña
                  TextField(
                    controller: _confirmarPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirmar contraseña',
                      labelStyle: TextStyle(color: AppColors.textoMedio),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: AppColors.primario,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.textoMedio,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: AppColors.fondoInput,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: AppColors.primario,
                          width: 2,
                        ),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textoOscuro),
                  ),

                  const SizedBox(height: 30),

                  // Botón guardar cambios
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _guardarCambios,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primario,
                        foregroundColor: AppColors.textoBlanco,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: AppColors.textoBlanco,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Guardar cambios',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // Botón cerrar sesión
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    onPressed: _cerrarSesion,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 10),
                        Text(
                          'Cerrar sesión',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }
}
