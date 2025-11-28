import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'detalle_evento_screen.dart';
import 'perfil_screen.dart';

class AppColors {
  static const Color primario = Color(0xFF4B5AE4);
  static const Color primarioClaro = Color(0xFF6B7FFF);
  static const Color fondoPrincipal = Color(0xFFF8F9FF);
  static const Color textoBlanco = Color(0xFFFFFFFF);
  static const Color textoOscuro = Color(0xFF1A1D2E);
  static const Color textoMedio = Color(0xFF6B7280);
  static const Color acento = Color(0xFF10B981);
}

class PrincipalScreen extends StatefulWidget {
  final String correoUsuario;
  final String nombreUsuario;
  final String? fotoPerfil;

  const PrincipalScreen({
    super.key,
    required this.correoUsuario,
    required this.nombreUsuario,
    this.fotoPerfil,
  });

  @override
  _PrincipalScreenState createState() => _PrincipalScreenState();
}

class _PrincipalScreenState extends State<PrincipalScreen> {
  int _selectedIndex = 0;
  int _previousIndex = 0;
  List<dynamic> eventos = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    cargarEventos();
  }

  Future<void> cargarEventos() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final url = Uri.parse(
      'http://192.168.56.1:8000/movil/mis-eventos/${widget.correoUsuario}',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final resultado = jsonDecode(response.body);
        setState(() {
          eventos = resultado['eventos'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Error al cargar eventos';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error de conexión: $e';
        isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = index;
    });
  }

  Widget _buildEventosScreen() {
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
                  'Mis Eventos',
                  style: TextStyle(
                    color: AppColors.textoBlanco,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: AppColors.textoBlanco,
                    size: 24,
                  ),
                  onPressed: cargarEventos,
                ),
              ],
            ),
          ),
        ),

        // Contenido de eventos
        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primario),
                )
              : errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 60,
                        color: AppColors.textoMedio,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        errorMessage,
                        style: const TextStyle(
                          color: AppColors.textoMedio,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: cargarEventos,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primario,
                        ),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : eventos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.event_busy,
                        size: 80,
                        color: AppColors.textoMedio,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No tienes eventos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textoOscuro,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Los eventos a los que seas invitado aparecerán aquí',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textoMedio,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: cargarEventos,
                  color: AppColors.primario,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Título de sección
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Todos los eventos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textoOscuro,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.acento,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${eventos.length}',
                              style: const TextStyle(
                                color: AppColors.textoBlanco,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Lista de eventos
                      ...eventos.map((evento) {
                        return EventoCard(
                          evento: evento,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetalleEventoScreen(
                                  idEvento: evento['id_evento'],
                                  correoUsuario: widget.correoUsuario,
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoPrincipal,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildEventosScreen(),
            PerfilScreen(
              correoUsuario: widget.correoUsuario,
              nombreUsuario: widget.nombreUsuario,
              fotoPerfil: widget.fotoPerfil,
              shouldReload: _selectedIndex == 1 && _previousIndex != 1,
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Eventos'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primario,
        unselectedItemColor: AppColors.textoMedio,
        onTap: _onItemTapped,
      ),
    );
  }
}

// Widget personalizado para las tarjetas de eventos
class EventoCard extends StatelessWidget {
  final dynamic evento;
  final VoidCallback onTap;

  const EventoCard({super.key, required this.evento, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool esActivo = evento['estado'] == 'activo';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.primario.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        evento['nombre_evento'] ?? 'Sin nombre',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textoOscuro,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: esActivo
                            ? AppColors.acento.withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        esActivo ? 'ACTIVO' : 'FINALIZADO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: esActivo ? AppColors.acento : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.textoMedio,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      evento['fecha_evento'] ?? '',
                      style: const TextStyle(
                        color: AppColors.textoMedio,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: AppColors.textoMedio,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${evento['hora_inicio']} - ${evento['hora_fin']}',
                      style: const TextStyle(
                        color: AppColors.textoMedio,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (evento['ubicacion'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.textoMedio,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          evento['ubicacion'],
                          style: const TextStyle(
                            color: AppColors.textoMedio,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: AppColors.textoMedio,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Organizado por: ${evento['organizador_nombre']}',
                      style: const TextStyle(
                        color: AppColors.textoMedio,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primario.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.qr_code,
                        size: 16,
                        color: AppColors.primario,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        evento['codigo_evento'] ?? '',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: AppColors.primario,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
